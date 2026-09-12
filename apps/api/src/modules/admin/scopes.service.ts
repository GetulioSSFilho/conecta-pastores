import { Injectable } from '@nestjs/common';
import { AuditAction, ScopeType } from '@prisma/client';
import { AppError } from '../../common/errors/app-error';
import { AuditService } from '../audit/audit.service';
import { UserPrincipalService } from '../auth/services/user-principal.service';
import { PrismaService } from '../../infra/prisma/prisma.service';
import type { AuthenticatedUser } from '../authorization/authorization.types';
import { CreateScopeDto, ReplaceUserRolesDto } from './dto/admin.dto';

@Injectable()
export class ScopesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly principals: UserPrincipalService,
  ) {}

  async userAccess(userId: string) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, deletedAt: null },
      select: { id: true, email: true, firstName: true, lastName: true, roles: { include: { role: true } }, scopes: true },
    });
    if (!user) throw AppError.notFound('Usuario nao encontrado.');
    return { ...user, roles: user.roles.map(({ role }) => role) };
  }

  async replaceRoles(actor: AuthenticatedUser, userId: string, dto: ReplaceUserRolesDto) {
    await this.assertUser(userId);
    const keys = [...new Set(dto.roleKeys.map((key) => key.trim().toUpperCase()))];
    const roles = await this.prisma.role.findMany({ where: { key: { in: keys } }, select: { id: true, key: true } });
    if (roles.length !== keys.length) {
      const found = new Set(roles.map((role) => role.key));
      throw AppError.validation('Role desconhecida.', { keys: keys.filter((key) => !found.has(key)) });
    }
    await this.prisma.$transaction(async (tx) => {
      await tx.userRole.deleteMany({ where: { userId } });
      if (roles.length) await tx.userRole.createMany({ data: roles.map((role) => ({ userId, roleId: role.id, grantedBy: actor.id })) });
    });
    this.principals.invalidate(userId);
    await this.audit.record({ userId: actor.id, action: AuditAction.ROLE_CHANGE, entity: 'User', entityId: userId, metadata: { roleKeys: keys } });
    return this.userAccess(userId);
  }

  async grant(actor: AuthenticatedUser, userId: string, dto: CreateScopeDto) {
    await this.assertUser(userId);
    await this.validateReference(dto.type, dto.refId);
    const scope = await this.prisma.userScope.create({
      data: {
        userId,
        type: dto.type,
        refId: dto.refId,
        permissionKeys: [...new Set(dto.permissionKeys ?? [])],
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : undefined,
        grantedBy: actor.id,
      },
    });
    this.principals.invalidate(userId);
    await this.audit.record({ userId: actor.id, action: AuditAction.PERMISSION_CHANGE, entity: 'UserScope', entityId: scope.id, metadata: { userId, type: dto.type, refId: dto.refId } });
    return scope;
  }

  async revoke(actor: AuthenticatedUser, scopeId: string) {
    const scope = await this.prisma.userScope.findUnique({ where: { id: scopeId }, select: { id: true, userId: true } });
    if (!scope) throw AppError.notFound('Escopo nao encontrado.');
    await this.prisma.userScope.delete({ where: { id: scopeId } });
    this.principals.invalidate(scope.userId);
    await this.audit.record({ userId: actor.id, action: AuditAction.PERMISSION_CHANGE, entity: 'UserScope', entityId: scopeId, metadata: { operation: 'REVOKE', userId: scope.userId } });
  }

  private async assertUser(userId: string) {
    const exists = await this.prisma.user.findFirst({ where: { id: userId, deletedAt: null }, select: { id: true } });
    if (!exists) throw AppError.notFound('Usuario nao encontrado.');
  }

  private async validateReference(type: ScopeType, refId?: string) {
    const refRequired = type === ScopeType.COUNTRY || type === ScopeType.REGION || type === ScopeType.CHURCH;
    if (refRequired && !refId) throw AppError.validation('Este tipo de escopo exige refId.');
    if (!refRequired && refId) throw AppError.validation('Este tipo de escopo nao aceita refId.');
    if (!refId) return;
    const found = type === ScopeType.COUNTRY
      ? await this.prisma.country.findFirst({ where: { id: refId }, select: { id: true } })
      : type === ScopeType.REGION
        ? await this.prisma.region.findFirst({ where: { id: refId, deletedAt: null }, select: { id: true } })
        : await this.prisma.church.findFirst({ where: { id: refId, deletedAt: null }, select: { id: true } });
    if (!found) throw AppError.validation('Referencia de escopo nao encontrada.');
  }
}
