import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { Request, Response } from 'express';
import { AppError, ErrorCode } from '../errors/app-error';

interface ErrorBody {
  statusCode: number;
  code: string;
  message: string;
  details?: unknown;
  path: string;
  timestamp: string;
  requestId?: string;
}

/**
 * Traduz qualquer excecao para o envelope de erro unico da API.
 * Stack trace nunca vai para o cliente.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request & { id?: string }>();

    const body = this.toBody(exception, req);

    if (body.statusCode >= 500) {
      this.logger.error(
        { err: exception, requestId: body.requestId, path: body.path },
        exception instanceof Error ? exception.stack : 'Erro desconhecido',
      );
    } else {
      this.logger.warn({ code: body.code, path: body.path, requestId: body.requestId }, body.message);
    }

    res.status(body.statusCode).json(body);
  }

  private toBody(exception: unknown, req: Request & { id?: string }): ErrorBody {
    const base = {
      path: req.originalUrl ?? req.url,
      timestamp: new Date().toISOString(),
      requestId: req.id,
    };

    if (exception instanceof AppError) {
      const payload = exception.getResponse() as { code: ErrorCode; message: string; details?: unknown };
      return { statusCode: exception.getStatus(), ...payload, ...base };
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const raw = exception.getResponse();
      const message =
        typeof raw === 'string' ? raw : ((raw as { message?: string | string[] }).message ?? exception.message);
      return {
        statusCode: status,
        code: this.codeForStatus(status),
        message: Array.isArray(message) ? 'Dados invalidos.' : message,
        details: Array.isArray(message) ? message : undefined,
        ...base,
      };
    }

    if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      return { ...this.fromPrisma(exception), ...base };
    }

    return {
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      code: ErrorCode.INTERNAL_ERROR,
      message: 'Erro interno. Tente novamente.',
      ...base,
    };
  }

  private fromPrisma(
    e: Prisma.PrismaClientKnownRequestError,
  ): Pick<ErrorBody, 'statusCode' | 'code' | 'message' | 'details'> {
    switch (e.code) {
      case 'P2002':
        return {
          statusCode: HttpStatus.CONFLICT,
          code: ErrorCode.CONFLICT,
          message: 'Ja existe um registro com esses dados.',
          details: { fields: e.meta?.target },
        };
      case 'P2003':
        return {
          statusCode: HttpStatus.CONFLICT,
          code: ErrorCode.CONFLICT,
          message: 'Registro referenciado por outros dados.',
        };
      case 'P2025':
        return {
          statusCode: HttpStatus.NOT_FOUND,
          code: ErrorCode.NOT_FOUND,
          message: 'Registro nao encontrado.',
        };
      default:
        return {
          statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
          code: ErrorCode.INTERNAL_ERROR,
          message: 'Erro ao acessar dados.',
        };
    }
  }

  private codeForStatus(status: number): ErrorCode {
    const map: Record<number, ErrorCode> = {
      400: ErrorCode.VALIDATION_ERROR,
      401: ErrorCode.UNAUTHORIZED,
      403: ErrorCode.FORBIDDEN,
      404: ErrorCode.NOT_FOUND,
      409: ErrorCode.CONFLICT,
      422: ErrorCode.UNPROCESSABLE,
      429: ErrorCode.RATE_LIMITED,
    };
    return map[status] ?? ErrorCode.INTERNAL_ERROR;
  }
}
