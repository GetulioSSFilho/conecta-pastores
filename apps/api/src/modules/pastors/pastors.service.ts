import { Injectable } from '@nestjs/common';
import { AuditAction, Prisma, UserStatus } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AppError } from '../../common/errors/app-error';
import { PageDto } from '../../common/dto/pagination.dto';
import { toE164 } from '../../common/utils/phone.util';
import { daysSince, daysUntil } from '../../common/utils/date.util';
import { AuditService } from '../audit/audit.service';
import { AccessControlService } from '../authorization/access-control.service';
import { PERMISSIONS } from '../authorization/permissions.constants';
import { HierarchyService } from '../hierarchy/hierarchy.service';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import type { CreatePastorDto, PastorQueryDto, UpdatePastorDto } from './dto/pastor.dto';

/**
 * Cadastro de pastores e Perfil 360.
 *
 * O perfil e servido em SECOES separadas (resumo, ministerio, rede, cuidado...).
 * Carregar tudo de uma vez tornaria a tela lenta e traria dados que o usuario
 * talvez nem tenha permissao de ver.
 */
@Injectable()
export class PastorsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly acl: AccessControlService,
    private readonly hierarchy: HierarchyService,
    private readonly audit: AuditService,
  ) {}

  // ---------------------------------------------------------------------------
  // Listagem / diretorio
  // ---------------------------------------------------------------------------

  async list(user: AuthenticatedUser, query: PastorQueryDto) {
    const scopeWhere = await this.acl.pastorWhere(user, PERMISSIONS.PASTOR_READ);

    const where: Prisma.PastorWhereInput = {
      AND: [
        { deletedAt: null },
        scopeWhere,
        ...(query.status ? [{ status: query.status }] : []),
        ...(query.countryId ? [{ countryId: query.countryId }] : []),
        ...(query.regionId ? [{ regionId: query.regionId }] : []),
        ...(query.churchId ? [{ churchId: query.churchId }] : []),
        ...(query.ministryRoleId ? [{ ministryRoleId: query.ministryRoleId }] : []),
        ...(query.city ? [{ city: { contains: query.city, mode: 'insensitive' as const } }] : []),
        ...(query.supervisorId
          ? [{ ancestorsClosure: { some: { ancestorId: query.supervisorId, depth: 1 } } }]
          : []),
        ...(query.careOverdueDays
          ? [
              {
                OR: [
                  { lastCareAt: null },
                  { lastCareAt: { lt: new Date(Date.now() - query.careOverdueDays * 86_400_000) } },
                ],
              },
            ]
          : []),
        ...(query.search ? [this.searchClause(query.search)] : []),
      ],
    };

    const [total, data] = await this.prisma.$transaction([
      this.prisma.pastor.count({ where }),
      this.prisma.pastor.findMany({
        where,
        orderBy: this.orderBy(query),
        skip: query.skip,
        take: query.take,
        select: {
          id: true,
          pastoralName: true,
          firstName: true,
          lastName: true,
          photoUrl: true,
          email: true,
          phoneE164: true,
          whatsappE164: true,
          status: true,
          ministryTitle: true,
          city: true,
          lastCareAt: true,
          nextCareAt: true,
          church: { select: { id: true, name: true } },
          region: { select: { id: true, name: true, code: true } },
          country: { select: { id: true, name: true, code: true } },
          ministryRole: { select: { id: true, name: true } },
        },
      }),
    ]);

    return PageDto.of(
      data.map((p) => ({
        ...p,
        indicators: {
          daysSinceLastCare: daysSince(p.lastCareAt),
          neverCared: p.lastCareAt === null,
          daysUntilNextCare: daysUntil(p.nextCareAt),
        },
      })),
      total,
      query,
    );
  }

  // ---------------------------------------------------------------------------
  // Perfil 360 - uma consulta por secao
  // ---------------------------------------------------------------------------

  /** RESUMO: dados de identificacao e contato. */
  async summarySection(user: AuthenticatedUser, pastorId: string) {
    await this.acl.assertPastorAccess(user, pastorId);
    const canSeeAdminNotes = this.acl.has(user, PERMISSIONS.PASTOR_READ_ADMIN_NOTES);

    const pastor = await this.prisma.pastor.findFirstOrThrow({
      where: { id: pastorId, deletedAt: null },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        pastoralName: true,
        photoUrl: true,
        email: true,
        phoneE164: true,
        whatsappE164: true,
        birthDate: true,
        maritalStatus: true,
        spouseName: true,
        city: true,
        address: true,
        locale: true,
        timezone: true,
        status: true,
        biography: true,
        adminNotes: canSeeAdminNotes,
        lastCareAt: true,
        nextCareAt: true,
        createdAt: true,
        updatedAt: true,
        country: { select: { id: true, name: true, code: true } },
        region: { select: { id: true, name: true, code: true } },
        // Vinculo ministerial: o cadastro grava, o resumo precisa devolver.
        church: { select: { id: true, name: true, city: true } },
        ministryRole: { select: { id: true, name: true, key: true } },
        ministryTitle: true,
        joinedAt: true,
        ordainedAt: true,
        user: { select: { id: true, email: true, status: true, lastLoginAt: true } },
      },
    });

    if (this.acl.has(user, PERMISSIONS.PASTOR_READ_ADMIN_NOTES) && pastor.adminNotes) {
      await this.audit.record({
        userId: user.id,
        action: AuditAction.READ_CONFIDENTIAL,
        entity: 'Pastor',
        entityId: pastorId,
        metadata: { field: 'adminNotes' },
      });
    }

    return {
      ...pastor,
      indicators: {
        daysSinceLastCare: daysSince(pastor.lastCareAt),
        neverCared: pastor.lastCareAt === null,
        daysUntilNextCare: daysUntil(pastor.nextCareAt),
      },
    };
  }

  /** MINISTERIO: funcao, titulo, datas e igreja. */
  async ministrySection(user: AuthenticatedUser, pastorId: string) {
    await this.acl.assertPastorAccess(user, pastorId);
    return this.prisma.pastor.findFirstOrThrow({
      where: { id: pastorId, deletedAt: null },
      select: {
        id: true,
        ministryTitle: true,
        joinedAt: true,
        ordainedAt: true,
        status: true,
        ministryRole: { select: { id: true, key: true, name: true } },
        church: {
          select: {
            id: true,
            name: true,
            code: true,
            type: true,
            city: true,
            status: true,
            country: { select: { id: true, name: true, code: true } },
            region: { select: { id: true, name: true } },
          },
        },
        leadsChurch: { select: { id: true, name: true } },
      },
    });
  }

  /** LIDERANCA: cadeia acima do pastor. */
  async leadershipSection(user: AuthenticatedUser, pastorId: string) {
    await this.acl.assertPastorAccess(user, pastorId, PERMISSIONS.NETWORK_READ);
    const [ancestors, supervisorId] = await Promise.all([
      this.hierarchy.ancestors(pastorId),
      this.hierarchy.currentSupervisorId(pastorId),
    ]);
    return {
      supervisorId,
      chain: ancestors,
    };
  }

  /** MINHA REDE: subordinados diretos + metricas. */
  async networkSection(user: AuthenticatedUser, pastorId: string) {
    await this.acl.assertPastorAccess(user, pastorId, PERMISSIONS.NETWORK_READ);
    const [directReports, stats] = await Promise.all([
      this.hierarchy.directReports(pastorId),
      this.hierarchy.stats(pastorId),
    ]);
    return { stats, directReports };
  }

  /** HISTORICO: trilha de auditoria da entidade. */
  async historySection(user: AuthenticatedUser, pastorId: string, take = 50) {
    await this.acl.assertPastorAccess(user, pastorId);
    this.acl.assert(user, PERMISSIONS.AUDIT_READ);
    return this.prisma.auditLog.findMany({
      where: { entity: 'Pastor', entityId: pastorId },
      orderBy: { createdAt: 'desc' },
      take,
      select: {
        id: true,
        action: true,
        metadata: true,
        createdAt: true,
        user: { select: { id: true, firstName: true, lastName: true } },
      },
    });
  }

  // ---------------------------------------------------------------------------
  // Escrita
  // ---------------------------------------------------------------------------

  async create(user: AuthenticatedUser, dto: CreatePastorDto) {
    await this.validateReferences(dto);

    const pastor = await this.prisma.$transaction(async (tx) => {
      const created = await tx.pastor.create({
        data: this.toPersistence(dto, true),
        select: { id: true, pastoralName: true },
      });

      await tx.pastoralClosure.create({
        data: { ancestorId: created.id, descendantId: created.id, depth: 0 },
      });

      return created;
    });

    if (dto.supervisorId) {
      await this.hierarchy.setSupervisor(pastor.id, dto.supervisorId, user);
    }

    await this.audit.record({
      userId: user.id,
      action: AuditAction.CREATE,
      entity: 'Pastor',
      entityId: pastor.id,
      metadata: { pastoralName: pastor.pastoralName },
    });

    return this.summarySection(user, pastor.id);
  }

  async update(user: AuthenticatedUser, pastorId: string, dto: UpdatePastorDto) {
    await this.acl.assertPastorAccess(user, pastorId, PERMISSIONS.PASTOR_WRITE);
    await this.validateReferences(dto);

    if (dto.adminNotes !== undefined) {
      this.acl.assert(user, PERMISSIONS.PASTOR_READ_ADMIN_NOTES);
    }

    await this.prisma.pastor.update({
      where: { id: pastorId },
      data: this.toPersistence(dto, false),
    });

    if (dto.supervisorId !== undefined) {
      const current = await this.hierarchy.currentSupervisorId(pastorId);
      if (current !== dto.supervisorId) {
        await this.hierarchy.setSupervisor(pastorId, dto.supervisorId ?? null, user);
      }
    }

    await this.audit.record({
      userId: user.id,
      action: AuditAction.UPDATE,
      entity: 'Pastor',
      entityId: pastorId,
      metadata: { fields: Object.keys(dto) },
    });

    return this.summarySection(user, pastorId);
  }

  /**
   * Soft delete. Historico de cuidado, documentos e auditoria sao preservados:
   * apagar o registro apagaria a memoria pastoral da pessoa.
   */
  async remove(user: AuthenticatedUser, pastorId: string) {
    await this.acl.assertPastorAccess(user, pastorId, PERMISSIONS.PASTOR_DELETE);

    const network = await this.hierarchy.stats(pastorId);
    if (network.directReports > 0) {
      throw AppError.conflict(
        'Pastor possui subordinados diretos. Reatribua a rede antes de desligar.',
        { directReports: network.directReports },
      );
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.pastor.update({ where: { id: pastorId }, data: { deletedAt: new Date() } });
      await tx.pastoralRelationship.updateMany({
        where: { subordinateId: pastorId, isActive: true },
        data: { isActive: false, endedAt: new Date() },
      });
      await tx.pastoralClosure.deleteMany({
        where: { OR: [{ ancestorId: pastorId }, { descendantId: pastorId }] },
      });
      await tx.user.updateMany({
        where: { pastor: { id: pastorId } },
        data: { status: UserStatus.DISABLED },
      });
    });

    await this.audit.record({
      userId: user.id,
      action: AuditAction.DELETE,
      entity: 'Pastor',
      entityId: pastorId,
    });
  }

  // ---------------------------------------------------------------------------
  // Internos
  // ---------------------------------------------------------------------------

  private searchClause(search: string): Prisma.PastorWhereInput {
    const term = search.trim();
    return {
      OR: [
        { pastoralName: { contains: term, mode: 'insensitive' } },
        { firstName: { contains: term, mode: 'insensitive' } },
        { lastName: { contains: term, mode: 'insensitive' } },
        { email: { contains: term, mode: 'insensitive' } },
        { city: { contains: term, mode: 'insensitive' } },
        { church: { name: { contains: term, mode: 'insensitive' } } },
      ],
    };
  }

  private orderBy(query: PastorQueryDto): Prisma.PastorOrderByWithRelationInput[] {
    const dir = query.sortOrder ?? 'asc';
    switch (query.sortBy) {
      case 'lastCareAt':
        return [{ lastCareAt: { sort: dir, nulls: 'first' } }];
      case 'status':
        return [{ status: dir }, { pastoralName: 'asc' }];
      case 'church':
        return [{ church: { name: dir } }, { pastoralName: 'asc' }];
      case 'createdAt':
        return [{ createdAt: dir }];
      default:
        return [{ pastoralName: dir }];
    }
  }

  private async validateReferences(dto: CreatePastorDto | UpdatePastorDto): Promise<void> {
    if (dto.countryId) {
      const country = await this.prisma.country.findUnique({ where: { id: dto.countryId } });
      if (!country) throw AppError.validation('Pais invalido.');
    }
    if (dto.regionId) {
      const region = await this.prisma.region.findFirst({
        where: { id: dto.regionId, deletedAt: null },
        select: { countryId: true },
      });
      if (!region) throw AppError.validation('Regiao invalida.');
      if (dto.countryId && region.countryId !== dto.countryId) {
        throw AppError.validation('A regiao informada nao pertence ao pais informado.');
      }
    }
    if (dto.churchId) {
      const church = await this.prisma.church.findFirst({
        where: { id: dto.churchId, deletedAt: null },
        select: { id: true },
      });
      if (!church) throw AppError.validation('Igreja invalida.');
    }
  }

  private toPersistence(
    dto: CreatePastorDto | UpdatePastorDto,
    isCreate: boolean,
  ): Prisma.PastorUncheckedCreateInput & Prisma.PastorUncheckedUpdateInput {
    const pastoralName =
      dto.pastoralName ?? (dto.firstName && dto.lastName ? `${dto.firstName} ${dto.lastName}` : undefined);

    const data = {
      firstName: dto.firstName,
      lastName: dto.lastName,
      pastoralName,
      email: dto.email,
      phoneE164: dto.phone !== undefined ? toE164(dto.phone) : undefined,
      whatsappE164: dto.whatsapp !== undefined ? toE164(dto.whatsapp) : undefined,
      birthDate: dto.birthDate ? new Date(dto.birthDate) : undefined,
      maritalStatus: dto.maritalStatus,
      spouseName: dto.spouseName,
      spouseBirthDate: dto.spouseBirthDate ? new Date(dto.spouseBirthDate) : undefined,
      countryId: dto.countryId,
      regionId: dto.regionId,
      city: dto.city,
      address: dto.address,
      postalCode: dto.postalCode,
      locale: dto.locale,
      timezone: dto.timezone,
      churchId: dto.churchId,
      ministryRoleId: dto.ministryRoleId,
      ministryTitle: dto.ministryTitle,
      joinedAt: dto.joinedAt ? new Date(dto.joinedAt) : undefined,
      ordainedAt: dto.ordainedAt ? new Date(dto.ordainedAt) : undefined,
      status: dto.status,
      biography: dto.biography,
      adminNotes: dto.adminNotes,
    };

    if (isCreate) {
      return data as unknown as Prisma.PastorUncheckedCreateInput & Prisma.PastorUncheckedUpdateInput;
    }
    // Update: remove chaves undefined para nao sobrescrever com null.
    return Object.fromEntries(
      Object.entries(data).filter(([, v]) => v !== undefined),
    ) as unknown as Prisma.PastorUncheckedCreateInput & Prisma.PastorUncheckedUpdateInput;
  }
}
