/**
 * Configuracao centralizada da aplicacao.
 * Todo acesso a variavel de ambiente passa por aqui - nunca `process.env` espalhado.
 */
export interface AppConfig {
  env: string;
  appEnv: 'DEV' | 'STAGING' | 'PRODUCTION';
  name: string;
  port: number;
  globalPrefix: string;
  publicUrl: string;
  webPublicUrl: string;
  corsOrigins: string[];
}

export interface JwtConfig {
  accessSecret: string;
  refreshSecret: string;
  accessTtl: string;
  refreshTtl: string;
  issuer: string;
  audience: string;
}

export interface ArgonConfig {
  memoryCost: number;
  timeCost: number;
  parallelism: number;
}

export interface RedisConfig {
  enabled: boolean;
  url: string;
}

export interface StorageConfig {
  driver: 'local' | 's3';
  localPath: string;
  endpoint: string;
  region: string;
  bucket: string;
  accessKey: string;
  secretKey: string;
  forcePathStyle: boolean;
  signedUrlTtl: number;
}

export interface RateLimitConfig {
  ttl: number;
  limit: number;
  authTtl: number;
  authLimit: number;
}

export interface Configuration {
  app: AppConfig;
  jwt: JwtConfig;
  argon: ArgonConfig;
  redis: RedisConfig;
  storage: StorageConfig;
  rateLimit: RateLimitConfig;
  queues: { enabled: boolean };
  push: { enabled: boolean; projectId: string; clientEmail: string; privateKey: string };
  log: { level: string; pretty: boolean };
}

const bool = (v: string | undefined, fallback = false): boolean =>
  v === undefined ? fallback : ['1', 'true', 'yes', 'on'].includes(v.toLowerCase());

const int = (v: string | undefined, fallback: number): number => {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
};

export default (): Configuration => ({
  app: {
    env: process.env.NODE_ENV ?? 'development',
    appEnv: (process.env.APP_ENV as AppConfig['appEnv']) ?? 'DEV',
    name: process.env.APP_NAME ?? 'Plataforma Pastoral',
    port: int(process.env.API_PORT, 3000),
    globalPrefix: process.env.API_GLOBAL_PREFIX ?? 'api',
    publicUrl: process.env.API_PUBLIC_URL ?? 'http://localhost:3000',
    webPublicUrl: process.env.WEB_PUBLIC_URL ?? 'http://localhost:8080',
    corsOrigins: (process.env.CORS_ORIGINS ?? 'http://localhost:8080')
      .split(',')
      .map((o) => o.trim())
      .filter(Boolean),
  },
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET ?? '',
    refreshSecret: process.env.JWT_REFRESH_SECRET ?? '',
    accessTtl: process.env.JWT_ACCESS_TTL ?? '15m',
    refreshTtl: process.env.JWT_REFRESH_TTL ?? '30d',
    issuer: process.env.JWT_ISSUER ?? 'plataforma-pastoral',
    audience: process.env.JWT_AUDIENCE ?? 'plataforma-pastoral-clients',
  },
  argon: {
    memoryCost: int(process.env.ARGON_MEMORY_COST, 19456),
    timeCost: int(process.env.ARGON_TIME_COST, 2),
    parallelism: int(process.env.ARGON_PARALLELISM, 1),
  },
  redis: {
    enabled: bool(process.env.REDIS_ENABLED, false),
    url: process.env.REDIS_URL ?? 'redis://localhost:6379',
  },
  storage: {
    driver: (process.env.STORAGE_DRIVER as StorageConfig['driver']) ?? 'local',
    localPath: process.env.STORAGE_LOCAL_PATH ?? './.storage',
    endpoint: process.env.S3_ENDPOINT ?? 'http://localhost:9000',
    region: process.env.S3_REGION ?? 'us-east-1',
    bucket: process.env.S3_BUCKET ?? 'pastoral',
    accessKey: process.env.S3_ACCESS_KEY ?? '',
    secretKey: process.env.S3_SECRET_KEY ?? '',
    forcePathStyle: bool(process.env.S3_FORCE_PATH_STYLE, true),
    signedUrlTtl: int(process.env.S3_SIGNED_URL_TTL, 900),
  },
  rateLimit: {
    ttl: int(process.env.RATE_LIMIT_TTL, 60),
    limit: int(process.env.RATE_LIMIT_LIMIT, 120),
    authTtl: int(process.env.AUTH_RATE_LIMIT_TTL, 300),
    authLimit: int(process.env.AUTH_RATE_LIMIT_LIMIT, 10),
  },
  queues: { enabled: bool(process.env.QUEUES_ENABLED, false) },
  push: {
    enabled: bool(process.env.FCM_ENABLED, false),
    projectId: process.env.FCM_PROJECT_ID ?? '',
    clientEmail: process.env.FCM_CLIENT_EMAIL ?? '',
    privateKey: (process.env.FCM_PRIVATE_KEY ?? '').replace(/\n/g, '\n'),
  },
  log: {
    level: process.env.LOG_LEVEL ?? 'info',
    pretty: bool(process.env.LOG_PRETTY, false),
  },
});
