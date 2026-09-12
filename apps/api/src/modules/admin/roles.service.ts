import { Injectable } from '@nestjs/common';
import { AuditAction, Prisma } from '@prisma/client';
import { AppError } from '../../common/errors/app-error';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../../infra/prisma/prisma.service';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { CreateRoleDto, ReplaceRolePermissionsDto, UpdateRoleDto } from './dto/admin.dto';

@Injectable()
export class RolesService {
  constructor(private readonly prisma: PrismaService, private readonly audit: AuditService) {}

  async list() {
    const roles = await this.prisma.role.findMany({
      orderBy: [{ rank: 'desc' }, { name: 'asc' }],
      include: {
        permissions: { include: { permission: true }, orderBy: { permission: { key: 'asc' } } },
        _count: { select: { users: true } },
      },
    });
    return roles.map((role) => ({
      ...role,
      permissions: role.permissions.map(({ permission }) => permission),
      usersCount: role._count.users,
      _count: undefined,
    }));
  }

  async permissions() {
    const permissions = await this.prisma.permission.findMany({ orderBy: [{ resource: 'asc' }, { action: 'asc' }] });
    const groups = new Map<string, typeof permissions>();
    for (const permission of permissions) {
      const group = groups.get(permission.resource) ?? [];
      group.push(permission);
      groups.set(permission.resource, group);
    }
    return [...groups.entries()].map(([resource, items]) => ({ resource, permissions: items }));
  }

  async create(actor: AuthenticatedUser, dto: CreateRoleDto) {
    const key = dto.key.trim().toUpperCase();
    const permissionIds = await this.permissionIds(dto.permissionKeys ?? []);
    const role = await this.prisma.role.create({
      data: {
        key,
        name: dto.name.trim(),
        description: dto.description,
        rank: dto.rank ?? 0,
        permissions: { create: permissionIds.map((permissionId) => ({ permission: { connect: { id: permissionId } } })) },
      },
      include: { permissions: { include: { permission: true } } },
    });
    await this.audit.record({ userId: actor.id, action: AuditAction.ROLE_CHANGE, entity: 'Role', entityId: role.id, metadata: { operation: 'CREATE', key } });
    return role;
  }

  async update(actor: AuthenticatedUser, id: string, dto: UpdateRoleDto) {
    const current = await this.prisma.role.findUnique({ where: { id } });
    if (!current) throw AppError.notFound('Role nao encontrada.');
    const updated = await this.prisma.role.update({
      where: { id },
      data: { name: dto.name?.trim(), description: dto.description, rank: dto.rank },
    });
    if (dto.permissionKeys) await this.replacePermissions(actor, id, { permissionKeys: dto.permissionKeys });
    await this.audit.record({ userId: actor.id, action: AuditAction.ROLE_CHANGE, entity: 'Role', entityId: id, metadata: { operation: 'UPDATE', system: current.isSystem } });
    return updated;
  }

  async replacePermissions(actor: AuthenticatedUser, id: string, dto: ReplaceRolePermissionsDto) {
    const role = await this.prisma.role.findUnique({ where: { id }, select: { id: true } });
    if (!role) throw AppError.notFound('Role nao encontrada.');
    const permissionIds = await this.permissionIds(dto.permissionKeys);
    await this.prisma.$transaction(async (tx) => {
      await tx.rolePermission.deleteMany({ where: { roleId: id } });
      if (permissionIds.length) await tx.rolePermission.createMany({ data: permissionIds.map((permissionId) => ({ roleId: id, permissionId })) });
    });
    await this.audit.record({ userId: actor.id, action: AuditAction.PERMISSION_CHANGE, entity: 'Role', entityId: id, metadata: { permissionKeys: dto.permissionKeys } });
    return this.prisma.role.findUnique({ where: { id }, include: { permissions: { include: { permission: true } } } });
  }

  async remove(actor: AuthenticatedUser, id: string) {
    const role = await this.prisma.role.findUnique({ where: { id }, include: { _count: { select: { users: true } } } });
    if (!role) throw AppError.notFound('Role nao encontrada.');
    if (role.isSystem) throw AppError.conflict('Roles de sistema nao podem ser removidas.');
    if (role._count.users > 0) throw AppError.conflict('Remova os usuarios da role antes de exclui-la.');
    await this.prisma.role.delete({ where: { id } });
    await this.audit.record({ userId: actor.id, action: AuditAction.DELETE, entity: 'Role', entityId: id });
  }

  private async permissionIds(keys: string[]): Promise<string[]> {
    const unique = [...new Set(keys.map((key) => key.trim()))];
    if (!unique.length) return [];
    const rows = await this.prisma.permission.findMany({ where: { key: { in: unique } }, select: { id: true, key: true } });
    if (rows.length !== unique.length) {
      const found = new Set(rows.map((row) => row.key));
      throw AppError.validation('Permissao desconhecida.', { keys: unique.filter((key) => !found.has(key)) });
    }
    return rows.map((row) => row.id);
  }
}
