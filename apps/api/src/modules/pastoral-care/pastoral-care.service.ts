import { Injectable } from '@nestjs/common';
import { AuditAction, CareStatus, Confidentiality, Prisma } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AppError, ErrorCode } from '../../common/errors/app-error';
import { PageDto } from '../../common/dto/pagination.dto';
import { daysSince, daysUntil } from '../../common/utils/date.util';
import { AuditService } from '../audit/audit.service';
import { AccessControlService } from '../authorization/access-control.service';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import type { CareQueryDto, CreateCareDto, UpdateCareDto } from './dto/pastoral-care.dto';

/**
 * Cuidado pastoral.
 *
 * CONFIDENCIALIDADE: quem pode ler o que e decidido AQUI, no servidor.
 *   NORMAL       - qualquer usuario com care.read dentro do escopo.
 *   RESTRITO     - cadeia de supervisao do pastor + care.read_restricted.
 *   CONFIDENCIAL - autor/responsavel do registro, ou care.read_confidential.
 *
 * Toda leitura de registro RESTRITO ou CONFIDENCIAL vai para a auditoria.
 */
@Injectable()
export class PastoralCareService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly acl: AccessControlService,
    private readonly audit: AuditService,
  ) {}

  // ---------------------------------------------------------------------------
  // Leitura
  // ---------------------------------------------------------------------------

  async list(user: AuthenticatedUser, query: CareQueryDto) {
    if (query.pastorId) {
      await this.acl.assertPastorAccess(user, query.pastorId, PERMISSIONS.CARE_READ);
    }

    const accessWhere = await this.acl.careWhere(user, { pastorId: query.pastorId });

    const where: Prisma.PastoralCareWhereInput = {
      AND: [
        accessWhere,
        ...(query.typeId ? [{ typeId: query.typeId }] : []),
        ...(query.status ? [{ status: query.status }] : []),
        ...(query.performedById ? [{ performedById: query.performedById }] : []),
        ...(query.from ? [{ occurredAt: { gte: new Date(query.from) } }] : []),
        ...(query.to ? [{ occurredAt: { lte: new Date(query.to) } }] : []),
        ...(query.search
          ? [
              {
                OR: [
                  { summary: { contains: query.search, mode: 'insensitive' as const } },
                  { nextAction: { contains: query.search, mode: 'insensitive' as const } },
                ],
              },
            ]
          : []),
      ],
    };

    const [total, data] = await this.prisma.$transaction([
      this.prisma.pastoralCare.count({ where }),
      this.prisma.pastoralCare.findMany({
        where,
        orderBy: { occurredAt: query.sortOrder === 'asc' ? 'asc' : 'desc' },
        skip: query.skip,
        take: query.take,
        select: this.listSelect(),
      }),
    ]);

    return PageDto.of(data, total, query);
  }

  async get(user: AuthenticatedUser, id: string) {
    const accessWhere = await this.acl.careWhere(user);
    const care = await this.prisma.pastoralCare.findFirst({
      where: { AND: [{ id }, accessWhere] },
      select: { ...this.listSelect(), notes: true, location: true, durationMinutes: true },
    });

    if (!care) {
      // Distingue "nao existe" de "existe mas voce nao pode ver".
      const exists = await this.prisma.pastoralCare.findFirst({
        where: { id, deletedAt: null },
        select: { id: true },
      });
      if (!exists) throw AppError.notFound('Acompanhamento nao encontrado.');
      throw AppError.forbidden(
        ErrorCode.CONFIDENTIAL_ACCESS_DENIED,
        'Este acompanhamento tem acesso restrito.',
      );
    }

    if (care.confidentiality !== Confidentiality.NORMAL) {
      await this.audit.record({
        userId: user.id,
        action: AuditAction.READ_CONFIDENTIAL,
        entity: 'PastoralCare',
        entityId: id,
        metadata: { confidentiality: care.confidentiality, pastorId: care.pastor.id },
      });
    }

    return care;
  }

  /** Linha do tempo de cuidado de um pastor, para o Perfil 360. */
  async timeline(user: AuthenticatedUser, pastorId: string, take = 20) {
    await this.acl.assertPastorAccess(user, pastorId, PERMISSIONS.CARE_READ);
    const accessWhere = await this.acl.careWhere(user, { pastorId });

    const [entries, pastor] = await this.prisma.$transaction([
      this.prisma.pastoralCare.findMany({
        where: accessWhere,
        orderBy: { occurredAt: 'desc' },
        take,
        select: this.listSelect(),
      }),
      this.prisma.pastor.findUniqueOrThrow({
        where: { id: pastorId },
        select: { lastCareAt: true, nextCareAt: true },
      }),
    ]);

    return {
      indicators: {
        daysSinceLastCare: daysSince(pastor.lastCareAt),
        neverCared: pastor.lastCareAt === null,
        daysUntilNextCare: daysUntil(pastor.nextCareAt),
        lastCareAt: pastor.lastCareAt,
        nextCareAt: pastor.nextCareAt,
      },
      entries,
    };
  }

  /** Tipos de acompanhamento configurados. */
  async types() {
    return this.prisma.pastoralCareType.findMany({
      where: { isActive: true },
      orderBy: [{ rank: 'asc' }, { name: 'asc' }],
    });
  }

  // ---------------------------------------------------------------------------
  // Escrita
  // ---------------------------------------------------------------------------

  async create(user: AuthenticatedUser, dto: CreateCareDto) {
    await this.acl.assertPastorAccess(user, dto.pastorId, PERMISSIONS.CARE_WRITE);

    const confidentiality = dto.confidentiality ?? Confidentiality.NORMAL;
    if (!this.acl.assignableConfidentiality(user).includes(confidentiality)) {
      throw AppError.forbidden(
        ErrorCode.FORBIDDEN,
        'Voce nao pode registrar acompanhamento neste nivel de confidencialidade.',
      );
    }

    const type = await this.prisma.pastoralCareType.findUnique({ where: { id: dto.typeId } });
    if (!type) throw AppError.validation('Tipo de acompanhamento invalido.');

    // Responsavel padrao e quem registra. Delegar exige permissao de escrita.
    const performedById = dto.performedById ?? user.id;

    const care = await this.prisma.$transaction(async (tx) => {
      const created = await tx.pastoralCare.create({
        data: {
          pastorId: dto.pastorId,
          performedById,
          createdById: user.id,
          typeId: dto.typeId,
          occurredAt: new Date(dto.occurredAt),
          status: dto.status ?? CareStatus.DONE,
          summary: dto.summary,
          notes: dto.notes,
          nextAction: dto.nextAction,
          nextCareAt: dto.nextCareAt ? new Date(dto.nextCareAt) : undefined,
          confidentiality,
          durationMinutes: dto.durationMinutes,
          location: dto.location,
        },
        select: { id: true },
      });

      await this.refreshPastorCacheTx(tx, dto.pastorId);
      return created;
    });

    await this.audit.record({
      userId: user.id,
      action: AuditAction.CREATE,
      entity: 'PastoralCare',
      entityId: care.id,
      metadata: { pastorId: dto.pastorId, confidentiality },
    });

    return this.get(user, care.id);
  }

  async update(user: AuthenticatedUser, id: string, dto: UpdateCareDto) {
    const existing = await this.prisma.pastoralCare.findFirst({
      where: { id, deletedAt: null },
      select: { id: true, pastorId: true, performedById: true, createdById: true, confidentiality: true },
    });
    if (!existing) throw AppError.notFound('Acompanhamento nao encontrado.');

    await this.acl.assertPastorAccess(user, existing.pastorId, PERMISSIONS.CARE_WRITE);

    // Registro de outra pessoa so pode ser editado por quem tem escopo global de cuidado.
    const isOwner = existing.performedById === user.id || existing.createdById === user.id;
    if (!isOwner && !this.acl.has(user, PERMISSIONS.CARE_READ_CONFIDENTIAL)) {
      throw AppError.forbidden(
        ErrorCode.FORBIDDEN,
        'Apenas o responsavel pode editar este acompanhamento.',
      );
    }

    if (dto.confidentiality && !this.acl.assignableConfidentiality(user).includes(dto.confidentiality)) {
      throw AppError.forbidden(ErrorCode.FORBIDDEN, 'Nivel de confidencialidade nao permitido.');
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.pastoralCare.update({
        where: { id },
        data: {
          typeId: dto.typeId,
          occurredAt: dto.occurredAt ? new Date(dto.occurredAt) : undefined,
          status: dto.status,
          summary: dto.summary,
          notes: dto.notes,
          nextAction: dto.nextAction,
          nextCareAt: dto.nextCareAt ? new Date(dto.nextCareAt) : undefined,
          confidentiality: dto.confidentiality,
          durationMinutes: dto.durationMinutes,
          location: dto.location,
          performedById: dto.performedById,
        },
      });
      await this.refreshPastorCacheTx(tx, existing.pastorId);
    });

    await this.audit.record({
      userId: user.id,
      action: AuditAction.UPDATE,
      entity: 'PastoralCare',
      entityId: id,
      metadata: { fields: Object.keys(dto) },
    });

    return this.get(user, id);
  }

  /** Soft delete: historico de cuidado nao e apagado do banco. */
  async remove(user: AuthenticatedUser, id: string) {
    const existing = await this.prisma.pastoralCare.findFirst({
      where: { id, deletedAt: null },
      select: { pastorId: true, createdById: true },
    });
    if (!existing) throw AppError.notFound('Acompanhamento nao encontrado.');

    this.acl.assert(user, PERMISSIONS.CARE_DELETE);
    await this.acl.assertPastorAccess(user, existing.pastorId, PERMISSIONS.CARE_WRITE);

    await this.prisma.$transaction(async (tx) => {
      await tx.pastoralCare.update({ where: { id }, data: { deletedAt: new Date() } });
      await this.refreshPastorCacheTx(tx, existing.pastorId);
    });

    await this.audit.record({
      userId: user.id,
      action: AuditAction.DELETE,
      entity: 'PastoralCare',
      entityId: id,
      metadata: { pastorId: existing.pastorId },
    });
  }

  // ---------------------------------------------------------------------------
  // Internos
  // ---------------------------------------------------------------------------

  /**
   * Recalcula `lastCareAt` / `nextCareAt` do pastor.
   *
   * Sao campos denormalizados: sem eles, ordenar 1.000 pastores por
   * "dias sem acompanhamento" exigiria subconsulta correlacionada por linha.
   */
  private async refreshPastorCacheTx(tx: Prisma.TransactionClient, pastorId: string): Promise<void> {
    const now = new Date();

    const [last, next] = await Promise.all([
      tx.pastoralCare.findFirst({
        where: {
          pastorId,
          deletedAt: null,
          status: CareStatus.DONE,
          occurredAt: { lte: now },
        },
        orderBy: { occurredAt: 'desc' },
        select: { occurredAt: true },
      }),
      tx.pastoralCare.findFirst({
        where: {
          pastorId,
          deletedAt: null,
          nextCareAt: { gte: now },
          status: { notIn: [CareStatus.CANCELED] },
        },
        orderBy: { nextCareAt: 'asc' },
        select: { nextCareAt: true },
      }),
    ]);

    await tx.pastor.update({
      where: { id: pastorId },
      data: { lastCareAt: last?.occurredAt ?? null, nextCareAt: next?.nextCareAt ?? null },
    });
  }

  private listSelect() {
    return {
      id: true,
      occurredAt: true,
      status: true,
      summary: true,
      nextAction: true,
      nextCareAt: true,
      confidentiality: true,
      createdAt: true,
      updatedAt: true,
      type: { select: { id: true, key: true, name: true, icon: true, color: true } },
      pastor: { select: { id: true, pastoralName: true, photoUrl: true } },
      performedBy: { select: { id: true, firstName: true, lastName: true, avatarUrl: true } },
    } satisfies Prisma.PastoralCareSelect;
  }
}
