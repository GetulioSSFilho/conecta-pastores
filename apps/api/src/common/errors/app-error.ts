import { HttpException, HttpStatus } from '@nestjs/common';

/**
 * Codigos de erro estaveis consumidos pelo cliente Flutter.
 * O cliente decide a mensagem/i18n a partir do `code`, nunca do texto.
 */
export enum ErrorCode {
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  UNAUTHORIZED = 'UNAUTHORIZED',
  INVALID_CREDENTIALS = 'INVALID_CREDENTIALS',
  TOKEN_EXPIRED = 'TOKEN_EXPIRED',
  TOKEN_INVALID = 'TOKEN_INVALID',
  SESSION_REVOKED = 'SESSION_REVOKED',
  ACCOUNT_LOCKED = 'ACCOUNT_LOCKED',
  ACCOUNT_DISABLED = 'ACCOUNT_DISABLED',
  PASSWORD_CHANGE_REQUIRED = 'PASSWORD_CHANGE_REQUIRED',
  FORBIDDEN = 'FORBIDDEN',
  OUT_OF_SCOPE = 'OUT_OF_SCOPE',
  CONFIDENTIAL_ACCESS_DENIED = 'CONFIDENTIAL_ACCESS_DENIED',
  NOT_FOUND = 'NOT_FOUND',
  CONFLICT = 'CONFLICT',
  UNPROCESSABLE = 'UNPROCESSABLE',
  CYCLE_DETECTED = 'CYCLE_DETECTED',
  RATE_LIMITED = 'RATE_LIMITED',
  INTERNAL_ERROR = 'INTERNAL_ERROR',
  STORAGE_ERROR = 'STORAGE_ERROR',
}

export interface AppErrorPayload {
  code: ErrorCode;
  message: string;
  details?: unknown;
}

export class AppError extends HttpException {
  constructor(
    public readonly code: ErrorCode,
    message: string,
    status: HttpStatus,
    public readonly details?: unknown,
  ) {
    super({ code, message, details } satisfies AppErrorPayload, status);
  }

  static validation(message = 'Dados invalidos.', details?: unknown) {
    return new AppError(ErrorCode.VALIDATION_ERROR, message, HttpStatus.BAD_REQUEST, details);
  }
  static unauthorized(code = ErrorCode.UNAUTHORIZED, message = 'Nao autenticado.') {
    return new AppError(code, message, HttpStatus.UNAUTHORIZED);
  }
  static forbidden(code = ErrorCode.FORBIDDEN, message = 'Acesso negado.', details?: unknown) {
    return new AppError(code, message, HttpStatus.FORBIDDEN, details);
  }
  static notFound(message = 'Registro nao encontrado.') {
    return new AppError(ErrorCode.NOT_FOUND, message, HttpStatus.NOT_FOUND);
  }
  static conflict(message = 'Conflito de estado.', details?: unknown) {
    return new AppError(ErrorCode.CONFLICT, message, HttpStatus.CONFLICT, details);
  }
  static unprocessable(message = 'Nao foi possivel processar a requisicao.', details?: unknown) {
    return new AppError(ErrorCode.UNPROCESSABLE, message, HttpStatus.UNPROCESSABLE_ENTITY, details);
  }
  static internal(message = 'Erro interno.') {
    return new AppError(ErrorCode.INTERNAL_ERROR, message, HttpStatus.INTERNAL_SERVER_ERROR);
  }
}
