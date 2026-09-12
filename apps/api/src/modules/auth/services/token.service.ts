import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { AppConfigService } from '../../../config/config.service';
import { randomToken } from '../../../common/utils/crypto.util';
import type { AccessTokenPayload } from '../../authorization/authorization.types';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

/**
 * Emissao de tokens.
 *
 * Access token = JWT curto (15min) contendo somente `sub` e `sid`.
 * Refresh token = token opaco aleatorio (nao JWT): so o servidor sabe validar,
 * e o hash guardado permite revogacao imediata.
 */
@Injectable()
export class TokenService {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: AppConfigService,
  ) {}

  async issueAccessToken(userId: string, sessionId: string): Promise<string> {
    const payload: AccessTokenPayload = { sub: userId, sid: sessionId, typ: 'access' };
    return this.jwt.signAsync(payload, {
      secret: this.config.jwt.accessSecret,
      expiresIn: this.config.jwt.accessTtl,
      issuer: this.config.jwt.issuer,
      audience: this.config.jwt.audience,
    });
  }

  issueRefreshToken(): string {
    return randomToken(48);
  }

  refreshExpiryDate(): Date {
    return new Date(Date.now() + this.parseTtlMs(this.config.jwt.refreshTtl));
  }

  accessTtlSeconds(): number {
    return Math.floor(this.parseTtlMs(this.config.jwt.accessTtl) / 1000);
  }

  /** Converte "15m" / "30d" / "3600" em milissegundos. */
  private parseTtlMs(ttl: string): number {
    const match = /^(\d+)\s*([smhd])?$/.exec(ttl.trim());
    if (!match) return 900_000;
    const value = Number(match[1]);
    const unit = match[2] ?? 's';
    const factor = { s: 1000, m: 60_000, h: 3_600_000, d: 86_400_000 }[unit] ?? 1000;
    return value * factor;
  }
}
