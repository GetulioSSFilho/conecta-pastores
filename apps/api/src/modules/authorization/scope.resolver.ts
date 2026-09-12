import { Injectable, Logger } from '@nestjs/common';
import { Prisma, ScopeType } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import type { PermissionKey } from './permissions.constants';
import type { AuthenticatedUser, ScopeGrant } from './authorization.types';

/**
 * Traduz os escopos concedidos a um usuario em filtros Prisma.
 *
 * Regra central do produto: o backend NUNCA confia no cliente.
 * Toda listagem e todo acesso por id passam por um `where` produzido aqui.
 *
 * Custo das consultas:
 *  - SUBTREE usa a closure table (`pastoral_closure`), 1 index scan.
 *  - REGION expande a arvore de regioes com CTE recursiva + cache curto em memoria.
 */
@Injectable()
export class ScopeResolver {
  private readonly logger = new Logger(ScopeResolver.name);

  /** Cache de subarvores de regiao. Regioes mudam raramente. */
  private readonly regionTreeCache = new Map<string, { ids: string[]; expiresAt: number }>();
  private static readonly REGION_CACHE_TTL_MS = 60_000;

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Escopos aplicaveis a uma permissao especifica.
   * `permissionKeys` vazio = escopo amplo (vale para todas as permissoes do usuario).
   */
  grantsFor(user: AuthenticatedUser, permission: PermissionKey): ScopeGrant[] {
    return user.scopes.filter(
      (s) => s.permissionKeys.length === 0 || s.permissionKeys.includes(permission),
    );
  }

  hasGlobal(user: AuthenticatedUser, permission: PermissionKey): boolean {
    return this.grantsFor(user, permission).some((g) => g.type === ScopeType.GLOBAL);
  }

  /**
   * `where` de Pastor correspondente aos escopos do usuario para a permissao.
   * Retorna:
   *  - `{}`            -> acesso global (sem restricao adicional)
   *  - `{ id: { in: [] } }` -> nenhum acesso (nunca vaza dado)
   */
  async pastorWhere(
    user: AuthenticatedUser,
    permission: PermissionKey,
  ): Promise<Prisma.PastorWhereInput> {
    const grants = this.grantsFor(user, permission);
    if (grants.length === 0) return { id: { in: [] } };
    if (grants.some((g) => g.type === ScopeType.GLOBAL)) return {};

    const clauses: Prisma.PastorWhereInput[] = [];
    const countryIds: string[] = [];
    const churchIds: string[] = [];
    const regionIds: string[] = [];

    for (const grant of grants) {
      switch (grant.type) {
        case ScopeType.COUNTRY:
          if (grant.refId) countryIds.push(grant.refId);
          break;
        case ScopeType.REGION:
          if (grant.refId) regionIds.push(grant.refId);
          break;
        case ScopeType.CHURCH:
          if (grant.refId) churchIds.push(grant.refId);
          break;
        case ScopeType.SUBTREE:
          if (user.pastorId) {
            // Pastores cuja closure lista o usuario como ancestral (inclui ele mesmo, depth 0).
            clauses.push({ ancestorsClosure: { some: { ancestorId: user.pastorId } } });
          }
          break;
        case ScopeType.SELF:
          if (user.pastorId) clauses.push({ id: user.pastorId });
          break;
        default:
          break;
      }
    }

    if (countryIds.length) clauses.push({ countryId: { in: countryIds } });
    if (churchIds.length) clauses.push({ churchId: { in: churchIds } });
    if (regionIds.length) {
      const expanded = await this.expandRegions(regionIds);
      clauses.push({ regionId: { in: expanded } });
    }

    if (clauses.length === 0) return { id: { in: [] } };
    return clauses.length === 1 ? clauses[0] : { OR: clauses };
  }

  /** `where` de Church correspondente aos escopos do usuario. */
  async churchWhere(
    user: AuthenticatedUser,
    permission: PermissionKey,
  ): Promise<Prisma.ChurchWhereInput> {
    const grants = this.grantsFor(user, permission);
    if (grants.length === 0) return { id: { in: [] } };
    if (grants.some((g) => g.type === ScopeType.GLOBAL)) return {};

    const clauses: Prisma.ChurchWhereInput[] = [];
    const countryIds: string[] = [];
    const churchIds: string[] = [];
    const regionIds: string[] = [];

    for (const grant of grants) {
      switch (grant.type) {
        case ScopeType.COUNTRY:
          if (grant.refId) countryIds.push(grant.refId);
          break;
        case ScopeType.REGION:
          if (grant.refId) regionIds.push(grant.refId);
          break;
        case ScopeType.CHURCH:
          if (grant.refId) churchIds.push(grant.refId);
          break;
        case ScopeType.SUBTREE:
          if (user.pastorId) {
            clauses.push({ pastors: { some: { ancestorsClosure: { some: { ancestorId: user.pastorId } } } } });
          }
          break;
        case ScopeType.SELF:
          if (user.pastorId) clauses.push({ pastors: { some: { id: user.pastorId } } });
          break;
        default:
          break;
      }
    }

    if (countryIds.length) clauses.push({ countryId: { in: countryIds } });
    if (churchIds.length) clauses.push({ id: { in: churchIds } });
    if (regionIds.length) {
      const expanded = await this.expandRegions(regionIds);
      clauses.push({ regionId: { in: expanded } });
    }

    if (clauses.length === 0) return { id: { in: [] } };
    return clauses.length === 1 ? clauses[0] : { OR: clauses };
  }

  /**
   * Ids de pastores visiveis. Use apenas quando um `where` aninhado nao for possivel
   * (ex.: agregacoes SQL cruas) - a lista pode ser grande.
   */
  async visiblePastorIds(
    user: AuthenticatedUser,
    permission: PermissionKey,
    limit = 20_000,
  ): Promise<string[] | 'ALL'> {
    if (this.hasGlobal(user, permission)) return 'ALL';
    const where = await this.pastorWhere(user, permission);
    const rows = await this.prisma.pastor.findMany({
      where: { ...where, deletedAt: null },
      select: { id: true },
      take: limit,
    });
    return rows.map((r) => r.id);
  }

  /** Expande regioes para incluir toda a subarvore (estado -> regioes -> setores). */
  async expandRegions(regionIds: string[]): Promise<string[]> {
    const result = new Set<string>();
    const missing: string[] = [];
    const now = Date.now();

    for (const id of regionIds) {
      const cached = this.regionTreeCache.get(id);
      if (cached && cached.expiresAt > now) {
        cached.ids.forEach((i) => result.add(i));
      } else {
        missing.push(id);
      }
    }

    if (missing.length > 0) {
      const rows = await this.prisma.$queryRaw<Array<{ root: string; id: string }>>`
        WITH RECURSIVE tree AS (
          SELECT r.id, r.id AS root
          FROM regions r
          WHERE r.id = ANY(${missing}::uuid[])
          UNION ALL
          SELECT child.id, tree.root
          FROM regions child
          JOIN tree ON child.parent_id = tree.id
        )
        SELECT root, id FROM tree
      `;

      const grouped = new Map<string, string[]>();
      for (const row of rows) {
        const list = grouped.get(row.root) ?? [];
        list.push(row.id);
        grouped.set(row.root, list);
        result.add(row.id);
      }
      for (const [root, ids] of grouped) {
        this.regionTreeCache.set(root, { ids, expiresAt: now + ScopeResolver.REGION_CACHE_TTL_MS });
      }
    }

    return [...result];
  }

  /** Invalida o cache de regioes (chamar ao criar/mover regiao). */
  invalidateRegionCache(): void {
    this.regionTreeCache.clear();
  }
}
