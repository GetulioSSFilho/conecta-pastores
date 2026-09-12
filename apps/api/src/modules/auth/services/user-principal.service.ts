import { Injectable } from '@nestjs/common';
import { UserStatus } from '@prisma/client';
import { PrismaService } from '../../../infra/prisma/prisma.service';
import { AppError, ErrorCode } from '../../../common/errors/app-error';
import type { PermissionKey } from '../../authorization/permissions.constants';
import type { AuthenticatedUser, ScopeGrant } from '../../authorization/authorization.types';

/**
 * Monta o principal (roles + permissoes + escopos) a cada request autenticada.
 *
 * O access token carrega apenas `sub` e `sid`. Permissoes NAO viajam no token:
 * revogar um acesso deve ter efeito imediato, sem esperar o token expirar.
 * O custo e uma consulta indexada por request, mitigada por cache curto.
 */
@Injectable()
export class UserPrincipalService {
  private static readonly CACHE_TTL_MS = 15_000;
  private readonly cache = new Map<string, { principal: AuthenticatedUser; expiresAt: number }>();

  constructor(private readonly prisma: PrismaService) {}

  async build(userId: string, sessionId: string): Promise<AuthenticatedUser> {
    const cacheKey = `${userId}:${sessionId}`;
    const cached = this.cache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) return cached.principal;

    const user = await this.prisma.user.findFirst({
      where: { id: userId, deletedAt: null },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        locale: true,
        timezone: true,
        status: true,
        pastor: { select: { id: true } },
        roles: {
          select: {
            role: {
              select: {
                key: true,
                permissions: { select: { permission: { select: { key: true } } } },
              },
            },
          },
        },
        scopes: {
          select: { type: true, refId: true, permissionKeys: true, expiresAt: true },
        },
      },
    });

    if (!user) throw AppError.unauthorized(ErrorCode.TOKEN_INVALID, 'Usuario inexistente.');
    if (user.status === UserStatus.DISABLED || user.status === UserStatus.SUSPENDED) {
      throw AppError.unauthorized(ErrorCode.ACCOUNT_DISABLED, 'Conta desativada.');
    }

    const now = new Date();
    const permissions = [
      ...new Set(
        user.roles.flatMap((ur) => ur.role.permissions.map((rp) => rp.permission.key)),
      ),
    ] as PermissionKey[];

    const scopes: ScopeGrant[] = user.scopes
      .filter((s) => !s.expiresAt || s.expiresAt > now)
      .map((s) => ({ type: s.type, refId: s.refId, permissionKeys: s.permissionKeys }));

    const principal: AuthenticatedUser = {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      locale: user.locale,
      timezone: user.timezone,
      pastorId: user.pastor?.id ?? null,
      roles: user.roles.map((ur) => ur.role.key),
      permissions,
      scopes,
      sessionId,
    };

    this.cache.set(cacheKey, {
      principal,
      expiresAt: Date.now() + UserPrincipalService.CACHE_TTL_MS,
    });
    return principal;
  }

  /** Invalida o cache do usuario (chamar ao alterar roles, escopos ou status). */
  invalidate(userId: string): void {
    for (const key of this.cache.keys()) {
      if (key.startsWith(`${userId}:`)) this.cache.delete(key);
    }
  }
}
