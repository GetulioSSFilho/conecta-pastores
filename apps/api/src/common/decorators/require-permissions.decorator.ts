import { SetMetadata } from '@nestjs/common';
import type { PermissionKey } from '../../modules/authorization/permissions.constants';

export const PERMISSIONS_KEY = 'requiredPermissions';

/**
 * Exige que o usuario possua TODAS as permissoes informadas.
 * O escopo de dados e aplicado separadamente pelos services.
 */
export const RequirePermissions = (...permissions: PermissionKey[]) =>
  SetMetadata(PERMISSIONS_KEY, permissions);
