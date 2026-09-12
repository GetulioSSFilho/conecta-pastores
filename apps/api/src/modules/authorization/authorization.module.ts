import { Global, Module } from '@nestjs/common';
import { AccessControlService } from './access-control.service';
import { ScopeResolver } from './scope.resolver';
import { PermissionsGuard } from './guards/permissions.guard';

/**
 * Modulo de autorizacao. Global porque praticamente todo modulo de dominio
 * precisa consultar escopo antes de retornar qualquer registro.
 */
@Global()
@Module({
  providers: [ScopeResolver, AccessControlService, PermissionsGuard],
  exports: [ScopeResolver, AccessControlService, PermissionsGuard],
})
export class AuthorizationModule {}
