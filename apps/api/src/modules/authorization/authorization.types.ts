import type { ScopeType } from '@prisma/client';
import type { PermissionKey } from './permissions.constants';

/** Escopo concedido, ja resolvido a partir de UserScope. */
export interface ScopeGrant {
  type: ScopeType;
  refId: string | null;
  /** Vazio = vale para todas as permissoes do usuario. */
  permissionKeys: string[];
}

/**
 * Principal autenticado. Montado uma vez por request pela JwtStrategy.
 * Nunca confiar em nada vindo do cliente alem do token assinado.
 */
export interface AuthenticatedUser {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  locale: string;
  timezone: string;
  /** Pastor vinculado ao usuario, quando existir. */
  pastorId: string | null;
  roles: string[];
  permissions: PermissionKey[];
  scopes: ScopeGrant[];
  sessionId: string;
}

/** Payload do access token. Mantido pequeno: sem permissoes nem escopos. */
export interface AccessTokenPayload {
  sub: string;
  sid: string;
  typ: 'access';
  iat?: number;
  exp?: number;
}

export interface RefreshTokenPayload {
  sub: string;
  sid: string;
  typ: 'refresh';
  iat?: number;
  exp?: number;
}
