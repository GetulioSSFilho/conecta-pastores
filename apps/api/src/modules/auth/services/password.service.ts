import { Injectable } from '@nestjs/common';
import { Algorithm, hash, verify } from '@node-rs/argon2';
import { AppConfigService } from '../../../config/config.service';

/**
 * Hash de senha com Argon2id.
 * Parametros seguem a recomendacao OWASP (m=19MiB, t=2, p=1) e sao configuraveis.
 */
@Injectable()
export class PasswordService {
  constructor(private readonly config: AppConfigService) {}

  async hash(plain: string): Promise<string> {
    const { memoryCost, timeCost, parallelism } = this.config.argon;
    return hash(plain, {
      algorithm: Algorithm.Argon2id,
      memoryCost,
      timeCost,
      parallelism,
    });
  }

  /** Nunca lanca: senha malformada no banco retorna false. */
  async verify(hashed: string | null | undefined, plain: string): Promise<boolean> {
    if (!hashed) return false;
    try {
      return await verify(hashed, plain);
    } catch {
      return false;
    }
  }

  /**
   * Politica minima de senha. Aplicada tambem no DTO, aqui como ultima barreira.
   */
  static validate(password: string): string[] {
    const errors: string[] = [];
    if (password.length < 10) errors.push('Minimo de 10 caracteres.');
    if (!/[a-z]/.test(password)) errors.push('Inclua uma letra minuscula.');
    if (!/[A-Z]/.test(password)) errors.push('Inclua uma letra maiuscula.');
    if (!/\d/.test(password)) errors.push('Inclua um numero.');
    return errors;
  }
}
