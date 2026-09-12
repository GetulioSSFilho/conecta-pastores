import { Injectable } from '@nestjs/common';
import { AuditAction, Prisma } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AppError } from '../../common/errors/app-error';
import { PageDto } from '../../common/dto/pagination.dto';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';
import { toE164 } from '../../common/utils/phone.util';
import { AuditService } from '../audit/audit.service';
import { AccessControlService } from '../authorization/access-control.service';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import type { ChurchMapQueryDto, ChurchQueryDto, CreateChurchDto, UpdateChurchDto } from './dto/church.dto';

/** Profundidade maxima ao subir a arvore de igrejas procurando ciclo. */
const MAX_TREE_DEPTH = 32;

@Injectable()
export class ChurchesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly acl: AccessControlService,
    private readonly audit: AuditService,
  ) {}

  // ---------------------------------------------------------------------------
  // Leitura
  // ---------------------------------------------------------------------------

  async list(user: AuthenticatedUser, query: ChurchQueryDto) {
    const scopeWhere = await this.acl.churchWhere(user, PERMISSIONS.CHURCH_READ);

    const where: Prisma.ChurchWhereInput = {
      AND: [
        { deletedAt: null },
        scopeWhere,
        ...(query.countryId ? [{ countryId: query.countryId }] : []),
        ...(query.regionId ? [{ regionId: query.regionId }] : []),
        ...(query.status ? [{ status: query.status }] : []),
        ...(query.type ? [{ type: query.type }] : []),
        ...(query.parentId ? [{ parentId: query.parentId }] : []),
        ...(query.search ? [this.searchClause(query.search)] : []),
      ],
    };

    const [total, data] = await this.prisma.$transaction([
      this.prisma.church.count({ where }),
      this.prisma.church.findMany({
        where,
        orderBy: [{ name: 'asc' }],
        skip: query.skip,
        take: query.take,
        select: {
          id: true,
          code: true,
          name: true,
          type: true,
          status: true,
          city: true,
          parentId: true,
          country: { select: { id: true, code: true, name: true } },
          region: { select: { id: true, code: true, name: true } },
          leadPastor: { select: { id: true, pastoralName: true } },
          _count: { select: { pastors: true, children: true } },
        },
      }),
    ]);

    return PageDto.of(data, total, query);
  }

  async getById(user: AuthenticatedUser, id: string) {
    await this.acl.assertChurchAccess(user, id, PERMISSIONS.CHURCH_READ);
    return this.prisma.church.findFirstOrThrow({
      where: { id, deletedAt: null },
      include: {
        country: { select: { id: true, code: true, name: true } },
        region: { select: { id: true, code: true, name: true } },
        parent: { select: { id: true, name: true, code: true } },
        children: {
          where: { deletedAt: null },
          orderBy: { name: 'asc' },
          select: { id: true, name: true, code: true, type: true, status: true },
        },
        leadPastor: { select: { id: true, pastoralName: true, email: true, phoneE164: true } },
        _count: { select: { pastors: true, children: true } },
      },
    });
  }

  /** Pastores da igreja: cruza o escopo de igreja com o escopo de pastor. */
  async pastorsOfChurch(user: AuthenticatedUser, id: string, query: PaginationQueryDto) {
    await this.acl.assertChurchAccess(user, id, PERMISSIONS.CHURCH_READ);
    const pastorScope = await this.acl.pastorWhere(user, PERMISSIONS.PASTOR_READ);

    const where: Prisma.PastorWhereInput = {
      AND: [{ deletedAt: null }, { churchId: id }, pastorScope],
    };

    const [total, data] = await this.prisma.$transaction([
      this.prisma.pastor.count({ where }),
      this.prisma.pastor.findMany({
        where,
        orderBy: { pastoralName: 'asc' },
        skip: query.skip,
        take: query.take,
        select: {
          id: true,
          pastoralName: true,
          photoUrl: true,
          email: true,
          phoneE164: true,
          status: true,
          ministryTitle: true,
          ministryRole: { select: { id: true, name: true } },
        },
      }),
    ]);

    return PageDto.of(data, total, query);
  }

  /**
   * Pontos para o mapa mundial. So retorna igrejas com coordenadas
   * cadastradas; o agrupamento/clustering por zoom fica no cliente.
   */
  async mapPoints(user: AuthenticatedUser, query: ChurchMapQueryDto) {
    const scopeWhere = await this.acl.churchWhere(user, PERMISSIONS.CHURCH_READ);

    const where: Prisma.ChurchWhereInput = {
      AND: [
        { deletedAt: null },
        { latitude: { not: null } },
        { longitude: { not: null } },
        scopeWhere,
        ...(query.countryId ? [{ countryId: query.countryId }] : []),
      ],
    };

    const churches = await this.prisma.church.findMany({
      where,
      select: {
        id: true,
        name: true,
        city: true,
        latitude: true,
        longitude: true,
        country: { select: { code: true } },
        _count: { select: { pastors: true } },
      },
    });

    return churches.map((c) => ({
      id: c.id,
      name: c.name,
      city: c.city,
      latitude: c.latitude ? Number(c.latitude) : null,
      longitude: c.longitude ? Number(c.longitude) : null,
      countryCode: c.country.code,
      pastorCount: c._count.pastors,
    }));
  }

  // ---------------------------------------------------------------------------
  // Escrita
  // ---------------------------------------------------------------------------

  async create(user: AuthenticatedUser, dto: CreateChurchDto) {
    await this.validateReferences(dto);
    await this.assertCodeAvailable(dto.code);

    const created = await this.prisma.church.create({
      data: {
        code: dto.code,
        name: dto.name,
        type: dto.type,
        status: dto.status,
        parentId: dto.parentId,
        countryId: dto.countryId,
        regionId: dto.regionId,
        city: dto.city,
        address: dto.address,
        postalCode: dto.postalCode,
        latitude: dto.latitude,
        longitude: dto.longitude,
        phoneE164: dto.phone !== undefined ? toE164(dto.phone) : undefined,
        email: dto.email,
        timezone: dto.timezone,
        foundedAt: dto.foundedAt ? new Date(dto.foundedAt) : undefined,
        membersEstimate: dto.membersEstimate,
      },
    });

    await this.audit.record({
      userId: user.id,
      action: AuditAction.CREATE,
      entity: 'Church',
      entityId: created.id,
      metadata: { code: created.code, name: created.name },
    });

    return this.getById(user, created.id);
  }

  async update(user: AuthenticatedUser, id: string, dto: UpdateChurchDto) {
    await this.acl.assertChurchAccess(user, id, PERMISSIONS.CHURCH_WRITE);
    await this.validateReferences(dto);

    if (dto.code) await this.assertCodeAvailable(dto.code, id);

    if (dto.parentId !== undefined && dto.parentId !== null) {
      if (dto.parentId === id) {
        throw AppError.validation('Uma igreja nao pode ser sede de si mesma.');
      }
      await this.assertNoCycle(id, dto.parentId);
    }

    const data: Prisma.ChurchUncheckedUpdateInput = {
      code: dto.code,
      name: dto.name,
      type: dto.type,
      status: dto.status,
      parentId: dto.parentId,
      countryId: dto.countryId,
      regionId: dto.regionId,
      city: dto.city,
      address: dto.address,
      postalCode: dto.postalCode,
      latitude: dto.latitude,
      longitude: dto.longitude,
      phoneE164: dto.phone !== undefined ? toE164(dto.phone) : undefined,
      email: dto.email,
      timezone: dto.timezone,
      foundedAt: dto.foundedAt ? new Date(dto.foundedAt) : undefined,
      membersEstimate: dto.membersEstimate,
    };
    // Remove chaves undefined para nao sobrescrever com null no banco.
    const clean = Object.fromEntries(Object.entries(data).filter(([, v]) => v !== undefined));

    await this.prisma.church.update({ where: { id }, data: clean });

    await this.audit.record({
      userId: user.id,
      action: AuditAction.UPDATE,
      entity: 'Church',
      entityId: id,
      metadata: { fields: Object.keys(clean) },
    });

    return this.getById(user, id);
  }

  /** Define o pastor responsavel. Um pastor so pode liderar uma igreja por vez. */
  async setLeadPastor(user: AuthenticatedUser, id: string, pastorId: string) {
    await this.acl.assertChurchAccess(user, id, PERMISSIONS.CHURCH_WRITE);
    await this.acl.assertPastorAccess(user, pastorId, PERMISSIONS.PASTOR_READ);

    const conflicting = await this.prisma.church.findFirst({
      where: { leadPastorId: pastorId, id: { not: id }, deletedAt: null },
      select: { id: true, name: true },
    });
    if (conflicting) {
      throw AppError.conflict('Este pastor ja lidera outra igreja.', { churchId: conflicting.id });
    }

    await this.prisma.church.update({ where: { id }, data: { leadPastorId: pastorId } });

    await this.audit.record({
      userId: user.id,
      action: AuditAction.UPDATE,
      entity: 'Church',
      entityId: id,
      metadata: { field: 'leadPastorId', pastorId },
    });

    return this.getById(user, id);
  }

  /** Soft delete. Bloqueado enquanto houver pastores ou igrejas filhas. */
  async remove(user: AuthenticatedUser, id: string) {
    await this.acl.assertChurchAccess(user, id, PERMISSIONS.CHURCH_DELETE);

    const [pastorCount, childrenCount] = await Promise.all([
      this.prisma.pastor.count({ where: { churchId: id, deletedAt: null } }),
      this.prisma.church.count({ where: { parentId: id, deletedAt: null } }),
    ]);

    if (pastorCount > 0 || childrenCount > 0) {
      throw AppError.conflict('Igreja possui pastores ou igrejas filhas vinculadas.', {
        pastors: pastorCount,
        children: childrenCount,
      });
    }

    await this.prisma.church.update({ where: { id }, data: { deletedAt: new Date() } });

    await this.audit.record({
      userId: user.id,
      action: AuditAction.DELETE,
      entity: 'Church',
      entityId: id,
    });
  }

  // ---------------------------------------------------------------------------
  // Internos
  // ---------------------------------------------------------------------------

  private searchClause(search: string): Prisma.ChurchWhereInput {
    const term = search.trim();
    return {
      OR: [
        { name: { contains: term, mode: 'insensitive' } },
        { code: { contains: term, mode: 'insensitive' } },
        { city: { contains: term, mode: 'insensitive' } },
      ],
    };
  }

  private async assertCodeAvailable(code: string, ignoreId?: string): Promise<void> {
    const existing = await this.prisma.church.findFirst({
      where: { code, ...(ignoreId ? { id: { not: ignoreId } } : {}) },
      select: { id: true },
    });
    if (existing) throw AppError.conflict('Ja existe uma igreja com este codigo.');
  }

  /**
   * Sobe a arvore a partir de `newParentId` procurando `churchId`.
   * Limite de 32 niveis: suficiente para qualquer estrutura real e evita
   * loop infinito caso dados corrompidos ja formem um ciclo.
   */
  private async assertNoCycle(churchId: string, newParentId: string): Promise<void> {
    let currentId: string | null = newParentId;
    for (let depth = 0; depth < MAX_TREE_DEPTH; depth++) {
      if (currentId === null) return;
      if (currentId === churchId) {
        throw AppError.validation('Movimento invalido: geraria ciclo na arvore de igrejas.');
      }
      const parent: { parentId: string | null } | null = await this.prisma.church.findFirst({
        where: { id: currentId },
        select: { parentId: true },
      });
      if (!parent) throw AppError.validation('Igreja pai nao encontrada.');
      currentId = parent.parentId;
    }
    throw AppError.validation('Arvore de igrejas excede a profundidade maxima permitida.');
  }

  private async validateReferences(dto: CreateChurchDto | UpdateChurchDto): Promise<void> {
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
    if (dto.parentId) {
      const parent = await this.prisma.church.findFirst({
        where: { id: dto.parentId, deletedAt: null },
        select: { id: true },
      });
      if (!parent) throw AppError.validation('Igreja sede (parentId) nao encontrada.');
    }
  }
}
