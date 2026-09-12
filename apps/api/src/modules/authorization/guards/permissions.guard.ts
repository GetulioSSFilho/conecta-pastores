import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PERMISSIONS_KEY } from '../../../common/decorators/require-permissions.decorator';
import { AppError, ErrorCode } from '../../../common/errors/app-error';
import type { PermissionKey } from '../permissions.constants';
import type { AuthenticatedUser } from '../authorization.types';

/**
 * Verifica as permissoes declaradas com @RequirePermissions.
 * O escopo de dados NAO e verificado aqui - cabe ao service, que conhece a entidade.
 */
@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<PermissionKey[]>(PERMISSIONS_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!required || required.length === 0) return true;

    const request = context.switchToHttp().getRequest<{ user?: AuthenticatedUser }>();
    const user = request.user;
    if (!user) throw AppError.unauthorized();

    const missing = required.filter((p) => !user.permissions.includes(p));
    if (missing.length > 0) {
      throw AppError.forbidden(ErrorCode.FORBIDDEN, 'Permissao insuficiente.', { required: missing });
    }
    return true;
  }
}
