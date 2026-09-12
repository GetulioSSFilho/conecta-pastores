import { Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { LoggerModule } from 'nestjs-pino';
import { randomUUID } from 'node:crypto';

import { AppConfigModule } from './config/config.module';
import { PrismaModule } from './infra/prisma/prisma.module';
import { StorageModule } from './infra/storage/storage.module';
import { AllExceptionsFilter } from './common/filters/all-exceptions.filter';
import { JwtAuthGuard } from './modules/auth/guards/jwt-auth.guard';
import { PermissionsGuard } from './modules/authorization/guards/permissions.guard';

import { AuthModule } from './modules/auth/auth.module';
import { AuthorizationModule } from './modules/authorization/authorization.module';
import { AuditModule } from './modules/audit/audit.module';
import { HealthModule } from './modules/health/health.module';
import { GeographyModule } from './modules/geography/geography.module';
import { ChurchesModule } from './modules/churches/churches.module';
import { PastorsModule } from './modules/pastors/pastors.module';
import { HierarchyModule } from './modules/hierarchy/hierarchy.module';
import { PastoralCareModule } from './modules/pastoral-care/pastoral-care.module';
import { ChannelModule } from './modules/channel/channel.module';
import { RequestsModule } from './modules/requests/requests.module';
import { EventsModule } from './modules/events/events.module';
import { DocumentsModule } from './modules/documents/documents.module';
import { CredentialsModule } from './modules/credentials/credentials.module';
import { TrainingModule } from './modules/training/training.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { ReportsModule } from './modules/reports/reports.module';
import { AdminModule } from './modules/admin/admin.module';
import { UsersModule } from './modules/users/users.module';

/**
 * Raiz da aplicacao.
 *
 * Guards globais, em ordem:
 *  1. ThrottlerGuard    - rate limit
 *  2. JwtAuthGuard      - autenticacao (rotas @Public passam)
 *  3. PermissionsGuard  - permissoes declaradas com @RequirePermissions
 *
 * O escopo de dados NAO e resolvido por guard: cada service consulta
 * AccessControlService, que conhece a entidade e produz o filtro Prisma.
 */
@Module({
  imports: [
    AppConfigModule,
    LoggerModule.forRoot({
      pinoHttp: {
        level: process.env.LOG_LEVEL ?? 'info',
        genReqId: (req, res) => {
          const existing = (req.headers['x-request-id'] as string) ?? randomUUID();
          res.setHeader('x-request-id', existing);
          return existing;
        },
        transport:
          process.env.LOG_PRETTY === 'true'
            ? { target: 'pino-pretty', options: { singleLine: true, translateTime: 'SYS:HH:MM:ss' } }
            : undefined,
        redact: {
          paths: [
            'req.headers.authorization',
            'req.headers.cookie',
            'req.body.password',
            'req.body.newPassword',
            'req.body.currentPassword',
            'req.body.refreshToken',
            'res.headers["set-cookie"]',
          ],
          remove: true,
        },
        autoLogging: { ignore: (req) => req.url === '/api/health' },
      },
    }),
    ThrottlerModule.forRoot({
      throttlers: [
        // Leitura autenticada: uma SPA carrega varias secoes por tela.
        { name: 'default', ttl: 60_000, limit: 300 },
        { name: 'auth', ttl: 300_000, limit: 10 },
      ],
      // Somente nos testes automatizados (jest define NODE_ENV=test). A validacao de
      // ambiente impede NODE_ENV=test fora de APP_ENV=DEV.
      skipIf: () => process.env.NODE_ENV === 'test',
    }),
    ScheduleModule.forRoot(),

    PrismaModule,
    StorageModule,
    AuthorizationModule,
    AuthModule,
    AuditModule,
    HealthModule,

    UsersModule,
    GeographyModule,
    ChurchesModule,
    PastorsModule,
    HierarchyModule,
    PastoralCareModule,
    ChannelModule,
    RequestsModule,
    EventsModule,
    DocumentsModule,
    CredentialsModule,
    TrainingModule,
    NotificationsModule,
    ReportsModule,
    AdminModule,
  ],
  providers: [
    { provide: APP_FILTER, useClass: AllExceptionsFilter },
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: PermissionsGuard },
  ],
})
export class AppModule {}
