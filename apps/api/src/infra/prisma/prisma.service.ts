import { INestApplication, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { Prisma, PrismaClient } from '@prisma/client';

/**
 * Cliente Prisma unico da aplicacao.
 * Log de queries lentas ligado fora de producao para achar N+1 cedo.
 */
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    super({
      log: [
        { emit: 'event', level: 'query' },
        { emit: 'event', level: 'warn' },
        { emit: 'event', level: 'error' },
      ],
    });
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();

    if (process.env.APP_ENV !== 'PRODUCTION') {
      const slowMs = 300;
      (this as unknown as { $on: (e: string, cb: (ev: Prisma.QueryEvent) => void) => void }).$on(
        'query',
        (event) => {
          if (event.duration >= slowMs) {
            this.logger.warn(`Query lenta (${event.duration}ms): ${event.query}`);
          }
        },
      );
    }
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }

  async enableShutdownHooks(app: INestApplication): Promise<void> {
    process.on('beforeExit', () => {
      void app.close();
    });
  }

  /** Filtro padrao de soft delete. */
  static notDeleted = { deletedAt: null } as const;
}
