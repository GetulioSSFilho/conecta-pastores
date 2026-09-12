import { Injectable } from '@nestjs/common';
import { AuditAction } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';
import { AppError, ErrorCode } from '../../common/errors/app-error';
import { AuditService } from '../audit/audit.service';
import { AccessControlService } from '../authorization/access-control.service';
import { PERMISSIONS } from '../authorization/permissions.constants';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import type { CreateMinistryRoleDto, UpdateMinistryRoleDto } from './dto/ministry-role.dto';

/**
 * Funcoes ministeriais (configuraveis, sem enum fixo no schema).
 *
 * Leitura aceita CHURCH_WRITE OU GEOGRAPHY_READ: e um catalogo de apoio usado
 * tanto por quem cadastra igrejas quanto por quem so consulta geografia.
 * O decorator @RequirePermissions so expressa E (todas), por isso o OR e
 * verificado aqui no service.
 */
@Injectable()
export class MinistryRolesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly acl: AccessControlService,
    private readonly audit: AuditService,
  ) {}

  private assertReadAccess(user: AuthenticatedUser): void {
    if (!this.acl.hasAny(user, PERMISSIONS.CHURCH_WRITE, PERMISSIONS.GEOGRAPHY_READ)) {
      throw AppError.forbidden(ErrorCode.FORBIDDEN, 'Permissao insuficiente.', {
        required: [PERMISSIONS.CHURCH_WRITE, PERMISSIONS.GEOGRAPHY_READ],
      });
    }
  }

  async list(user: AuthenticatedUser, onlyActive = false) {
    this.assertReadAccess(user);
    return this.prisma.ministryRole.findMany({
      where: onlyActive ? { isActive: true } : {},
      orderBy: [{ rank: 'asc' }, { name: 'asc' }],
      select: {
        id: true,
        key: true,
        name: true,
        description: true,
        rank: true,
        isActive: true,
        _count: { select: { pastors: true } },
      },
    });
  }

  async getById(user: AuthenticatedUser, id: string) {
    this.assertReadAccess(user);
    const role = await this.prisma.ministryRole.findUnique({
      where: { id },
      select: {
        id: true,
        key: true,
        name: true,
        description: true,
        rank: true,
        isActive: true,
        _count: { select: { pastors: true } },
      },
    });
    if (!role) throw AppError.notFound('Funcao ministerial nao encontrada.');
    return role;
  }

  async create(user: AuthenticatedUser, dto: CreateMinistryRoleDto) {
    const existing = await this.prisma.ministryRole.findUnique({ where: { key: dto.key } });
    if (existing) throw AppError.conflict('Ja existe uma funcao ministerial com esta chave.');

    const created = await this.prisma.ministryRole.create({
      data: {
        key: dto.key,
        name: dto.name,
        description: dto.description,
        rank: dto.rank ?? 0,
        isActive: dto.isActive ?? true,
      },
    });

    await this.audit.record({
      userId: user.id,
      action: AuditAction.CREATE,
      entity: 'MinistryRole',
      entityId: created.id,
      metadata: { key: created.key },
    });

    return created;
  }

  async update(user: AuthenticatedUser, id: string, dto: UpdateMinistryRoleDto) {
    await this.getById(user, id);

    const updated = await this.prisma.ministryRole.update({
      where: { id },
      data: dto,
    });

    await this.audit.record({
      userId: user.id,
      action: AuditAction.UPDATE,
      entity: 'MinistryRole',
      entityId: id,
      metadata: { fields: Object.keys(dto) },
    });

    return updated;
  }
}
