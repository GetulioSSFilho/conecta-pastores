import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { Logger as PinoLogger } from 'nestjs-pino';
import compression from 'compression';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { AppConfigService } from './config/config.service';
import { PrismaService } from './infra/prisma/prisma.service';
import { AppError } from './common/errors/app-error';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  app.useLogger(app.get(PinoLogger));

  const config = app.get(AppConfigService);
  const { port, globalPrefix, corsOrigins, name, appEnv } = config.app;

  // Prefixo unico /api. Versionamento fica para quando houver quebra de contrato.
  app.setGlobalPrefix(globalPrefix);

  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.use(compression());

  app.enableCors({
    origin: corsOrigins,
    credentials: true,
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept-Language', 'X-Request-Id'],
    exposedHeaders: ['X-Request-Id'],
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
      exceptionFactory: (errors) =>
        AppError.validation(
          'Dados invalidos.',
          errors.map((e) => ({
            field: e.property,
            constraints: Object.values(e.constraints ?? {}),
          })),
        ),
    }),
  );

  const swagger = new DocumentBuilder()
    .setTitle(`${name} - API`)
    .setDescription(
      'API da Plataforma Pastoral. Autorizacao: ROLE + PERMISSION + SCOPE + RELATIONSHIP. ' +
        'Todo acesso a dados e filtrado no servidor pelo escopo do usuario.',
    )
    .setVersion('1.0')
    .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'bearer')
    .addServer(`/${globalPrefix}`)
    .build();

  const document = SwaggerModule.createDocument(app, swagger);
  SwaggerModule.setup(`${globalPrefix}/docs`, app, document, {
    swaggerOptions: { persistAuthorization: true, tagsSorter: 'alpha', operationsSorter: 'alpha' },
    customSiteTitle: `${name} - API Docs`,
  });

  await app.get(PrismaService).enableShutdownHooks(app);
  app.enableShutdownHooks();

  await app.listen(port, '0.0.0.0');

  const logger = app.get(PinoLogger);
  logger.log(`${name} [${appEnv}] em http://localhost:${port}/${globalPrefix}`);
  logger.log(`Swagger em http://localhost:${port}/${globalPrefix}/docs`);
}

void bootstrap();
