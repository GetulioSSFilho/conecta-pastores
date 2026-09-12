import { plainToInstance } from 'class-transformer';
import { IsBoolean, IsIn, IsInt, IsOptional, IsString, MinLength, validateSync } from 'class-validator';

/**
 * Validacao fail-fast das variaveis de ambiente na inicializacao.
 * Segredos fracos derrubam o boot em STAGING/PRODUCTION.
 */
class EnvironmentVariables {
  @IsOptional()
  @IsIn(['development', 'test', 'production'])
  NODE_ENV?: string;

  @IsOptional()
  @IsIn(['DEV', 'STAGING', 'PRODUCTION'])
  APP_ENV?: string;

  @IsString()
  @MinLength(1)
  DATABASE_URL!: string;

  @IsString()
  @MinLength(32, { message: 'JWT_ACCESS_SECRET deve ter no minimo 32 caracteres' })
  JWT_ACCESS_SECRET!: string;

  @IsString()
  @MinLength(32, { message: 'JWT_REFRESH_SECRET deve ter no minimo 32 caracteres' })
  JWT_REFRESH_SECRET!: string;

  @IsOptional()
  @IsInt()
  API_PORT?: number;
}

const WEAK_SECRETS = ['CHANGE_ME_ACCESS_SECRET_MIN_32_CHARS_LONG', 'CHANGE_ME_REFRESH_SECRET_MIN_32_CHARS_LONG'];

export function validateEnv(config: Record<string, unknown>): Record<string, unknown> {
  const parsed = plainToInstance(EnvironmentVariables, config, { enableImplicitConversion: true });
  const errors = validateSync(parsed, { skipMissingProperties: false });

  if (errors.length > 0) {
    const details = errors
      .map((e) => `  - ${e.property}: ${Object.values(e.constraints ?? {}).join(', ')}`)
      .join('\n');
    throw new Error(`Configuracao invalida:\n${details}`);
  }

  const appEnv = (config.APP_ENV as string) ?? 'DEV';
  if (config.NODE_ENV === 'test' && appEnv !== 'DEV') {
    throw new Error('NODE_ENV=test (rate limit desligado) so e permitido com APP_ENV=DEV.');
  }
  if (appEnv !== 'DEV') {
    const weak = WEAK_SECRETS.filter((s) => Object.values(config).includes(s));
    if (weak.length > 0) {
      throw new Error(`Secrets padrao detectados em ${appEnv}. Defina valores reais antes de subir.`);
    }
    if (parsed.JWT_ACCESS_SECRET === parsed.JWT_REFRESH_SECRET) {
      throw new Error('JWT_ACCESS_SECRET e JWT_REFRESH_SECRET devem ser diferentes.');
    }
  }

  return config;
}
