import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { AppConfigService } from '../../../config/config.service';
import { AppError, ErrorCode } from '../../../common/errors/app-error';
import { SessionService } from '../services/session.service';
import { UserPrincipalService } from '../services/user-principal.service';
import type { AccessTokenPayload, AuthenticatedUser } from '../../authorization/authorization.types';

/**
 * Valida o access token e monta o principal.
 * A sessao e verificada a cada request: logout/revogacao tem efeito imediato.
 */
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: AppConfigService,
    private readonly sessions: SessionService,
    private readonly principals: UserPrincipalService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.jwt.accessSecret,
      issuer: config.jwt.issuer,
      audience: config.jwt.audience,
    });
  }

  async validate(payload: AccessTokenPayload): Promise<AuthenticatedUser> {
    if (payload.typ !== 'access') {
      throw AppError.unauthorized(ErrorCode.TOKEN_INVALID, 'Tipo de token invalido.');
    }
    const active = await this.sessions.isActive(payload.sid);
    if (!active) {
      throw AppError.unauthorized(ErrorCode.SESSION_REVOKED, 'Sessao revogada.');
    }
    return this.principals.build(payload.sub, payload.sid);
  }
}
