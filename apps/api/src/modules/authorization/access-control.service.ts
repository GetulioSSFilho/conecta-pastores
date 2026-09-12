import { Injectable } from '@nestjs/common';
import { Confidentiality, Prisma } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AppError, ErrorCode } from '../../common/errors/app-error';
import { PERMISSIONS, type PermissionKey } from './permissions.constants';
import { ScopeResolver } from './scope.resolver';
import type { AuthenticatedUser } from './authorization.types';

/**
 * Ponto unico de decisao de acesso.
 *
 * Modelo: ROLE -> PERMISSION -> SCOPE -> RELATIONSHIP.
 *  1. A role concede permissoes (o QUE pode ser feito).
 *  2. O escopo delimita os dados (SOBRE QUEM pode ser feito).
 *  3. A hierarquia (closure table) alimenta o escopo SUBTREE.
 *
 * Nenhuma decisao depende do frontend. Esconder botao nao e seguranca.
 */
@Injectable()
export class AccessControlService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly scopes: ScopeResolver,
  ) {}

  // ---------------------------------------------------------------------------
  // Permissao (o QUE)
  // ---------------------------------------------------------------------------

  has(user: AuthenticatedUser, permission: PermissionKey): boolean {
    return user.permissions.includes(permission);
  }

  hasAny(user: AuthenticatedUser, ...permissions: PermissionKey[]): boolean {
    return permissions.some((p) => this.has(user, p));
  }

  assert(user: AuthenticatedUser, permission: PermissionKey): void {
    if (!this.has(user, permission)) {
      throw AppError.forbidden(ErrorCode.FORBIDDEN, 'Permissao insuficiente.', {
        required: permission,
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Escopo (SOBRE QUEM)
  // ---------------------------------------------------------------------------

  pastorWhere(user: AuthenticatedUser, permission: PermissionKey): Promise<Prisma.PastorWhereInput> {
    return this.scopes.pastorWhere(user, permission);
  }

  churchWhere(user: AuthenticatedUser, permission: PermissionKey): Promise<Prisma.ChurchWhereInput> {
    return this.scopes.churchWhere(user, permission);
  }

  /**
   * Verifica acesso a um pastor especifico.
   * Retorna false tambem quando o pastor nao existe - o chamador decide
   * entre 403 e 404 conforme o risco de enumeracao.
   */
  async canAccessPastor(
    user: AuthenticatedUser,
    pastorId: string,
    permission: PermissionKey = PERMISSIONS.PASTOR_READ,
  ): Promise<boolean> {
    if (!this.has(user, permission)) return false;
    const where = await this.pastorWhere(user, permission);
    const found = await this.prisma.pastor.findFirst({
      where: { AND: [{ id: pastorId, deletedAt: null }, where] },
      select: { id: true },
    });
    return found !== null;
  }

  /**
   * Garante acesso a um pastor. Lanca 403 quando fora do escopo.
   *
   * Nao usamos 404 aqui de proposito: o usuario ja sabe que o id existe quando
   * chega por link, e 403 comunica corretamente a fronteira de autorizacao.
   */
  async assertPastorAccess(
    user: AuthenticatedUser,
    pastorId: string,
    permission: PermissionKey = PERMISSIONS.PASTOR_READ,
  ): Promise<void> {
    const exists = await this.prisma.pastor.findFirst({
      where: { id: pastorId, deletedAt: null },
      select: { id: true },
    });
    if (!exists) throw AppError.notFound('Pastor nao encontrado.');

    const allowed = await this.canAccessPastor(user, pastorId, permission);
    if (!allowed) {
      throw AppError.forbidden(ErrorCode.OUT_OF_SCOPE, 'Pastor fora do seu escopo de acesso.');
    }
  }

  async assertChurchAccess(
    user: AuthenticatedUser,
    churchId: string,
    permission: PermissionKey = PERMISSIONS.CHURCH_READ,
  ): Promise<void> {
    this.assert(user, permission);
    const where = await this.churchWhere(user, permission);
    const found = await this.prisma.church.findFirst({
      where: { AND: [{ id: churchId, deletedAt: null }, where] },
      select: { id: true },
    });
    if (!found) {
      const exists = await this.prisma.church.findFirst({
        where: { id: churchId, deletedAt: null },
        select: { id: true },
      });
      if (!exists) throw AppError.notFound('Igreja nao encontrada.');
      throw AppError.forbidden(ErrorCode.OUT_OF_SCOPE, 'Igreja fora do seu escopo de acesso.');
    }
  }

  // ---------------------------------------------------------------------------
  // Relacionamento (hierarquia)
  // ---------------------------------------------------------------------------

  /** true quando `ancestorPastorId` esta acima de `descendantPastorId` na rede. */
  async isAncestorOf(ancestorPastorId: string, descendantPastorId: string): Promise<boolean> {
    if (ancestorPastorId === descendantPastorId) return true;
    const row = await this.prisma.pastoralClosure.findUnique({
      where: {
        ancestorId_descendantId: {
          ancestorId: ancestorPastorId,
          descendantId: descendantPastorId,
        },
      },
      select: { depth: true },
    });
    return row !== null;
  }

  /** true quando o usuario supervisiona diretamente (depth 1) o pastor. */
  async isDirectSupervisorOf(user: AuthenticatedUser, pastorId: string): Promise<boolean> {
    if (!user.pastorId) return false;
    const row = await this.prisma.pastoralClosure.findUnique({
      where: { ancestorId_descendantId: { ancestorId: user.pastorId, descendantId: pastorId } },
      select: { depth: true },
    });
    return row?.depth === 1;
  }

  // ---------------------------------------------------------------------------
  // Confidencialidade
  // ---------------------------------------------------------------------------

  /**
   * Niveis de confidencialidade que o usuario pode ler sobre um pastor.
   *
   *  NORMAL       -> qualquer um com care.read no escopo.
   *  RESTRICTED   -> cadeia de supervisao do pastor + care.read_restricted.
   *  CONFIDENTIAL -> autor/responsavel do registro, ou care.read_confidential.
   */
  async allowedConfidentialityLevels(
    user: AuthenticatedUser,
    pastorId: string,
  ): Promise<Confidentiality[]> {
    const levels: Confidentiality[] = [Confidentiality.NORMAL];

    const inChain = user.pastorId ? await this.isAncestorOf(user.pastorId, pastorId) : false;

    if (this.has(user, PERMISSIONS.CARE_READ_RESTRICTED) && (inChain || this.scopes.hasGlobal(user, PERMISSIONS.CARE_READ_RESTRICTED))) {
      levels.push(Confidentiality.RESTRICTED);
    }
    if (this.has(user, PERMISSIONS.CARE_READ_CONFIDENTIAL)) {
      levels.push(Confidentiality.CONFIDENTIAL);
    }
    return levels;
  }

  /**
   * `where` de PastoralCare aplicando escopo + confidencialidade.
   * Registros CONFIDENTIAL do proprio usuario sempre aparecem para ele.
   */
  async careWhere(
    user: AuthenticatedUser,
    options: { pastorId?: string } = {},
  ): Promise<Prisma.PastoralCareWhereInput> {
    const pastorScope = await this.pastorWhere(user, PERMISSIONS.CARE_READ);

    const confidentialityClauses: Prisma.PastoralCareWhereInput[] = [
      { confidentiality: Confidentiality.NORMAL },
      // Sempre visivel para quem registrou ou conduziu o acompanhamento.
      { performedById: user.id },
      { createdById: user.id },
    ];

    if (this.has(user, PERMISSIONS.CARE_READ_RESTRICTED)) {
      confidentialityClauses.push({
        confidentiality: Confidentiality.RESTRICTED,
        ...(user.pastorId && !this.scopes.hasGlobal(user, PERMISSIONS.CARE_READ_RESTRICTED)
          ? { pastor: { ancestorsClosure: { some: { ancestorId: user.pastorId } } } }
          : {}),
      });
    }
    if (this.has(user, PERMISSIONS.CARE_READ_CONFIDENTIAL)) {
      confidentialityClauses.push({ confidentiality: Confidentiality.CONFIDENTIAL });
    }

    return {
      deletedAt: null,
      ...(options.pastorId ? { pastorId: options.pastorId } : {}),
      pastor: { is: pastorScope },
      OR: confidentialityClauses,
    };
  }

  /**
   * Confidencialidades que o usuario pode ATRIBUIR ao criar/editar um registro.
   * Evita que alguem "esconda" registro num nivel que nao pode reler.
   */
  assignableConfidentiality(user: AuthenticatedUser): Confidentiality[] {
    const levels: Confidentiality[] = [Confidentiality.NORMAL];
    if (this.has(user, PERMISSIONS.CARE_READ_RESTRICTED)) levels.push(Confidentiality.RESTRICTED);
    if (this.has(user, PERMISSIONS.CARE_WRITE)) levels.push(Confidentiality.CONFIDENTIAL);
    return levels;
  }
}
