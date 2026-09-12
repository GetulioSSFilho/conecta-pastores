import { Injectable, Logger } from '@nestjs/common';
import type { AuditAction, Prisma } from '@prisma/client';
import { PrismaService } from '../../infra/prisma/prisma.service';

export interface AuditEntry {
  userId?: string | null;
  action: AuditAction;
  entity?: string;
  entityId?: string;
  metadata?: Prisma.InputJsonValue;
  ip?: string;
  userAgent?: string;
  requestId?: string;
}

/** Campos que nunca podem ser persistidos em AuditLog.metadata. */
const FORBIDDEN_KEYS = new Set([
  'password',
  'passwordHash',
  'currentPassword',
  'newPassword',
  'token',
  'accessToken',
  'refreshToken',
  'secret',
  'authorization',
]);

/**
 * Trilha de auditoria. Falha de escrita nunca derruba a operacao de negocio -
 * o erro e logado e a requisicao segue.
 */
@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  async record(entry: AuditEntry): Promise<void> {
    try {
      await this.prisma.auditLog.create({
        data: {
          userId: entry.userId ?? null,
          action: entry.action,
          entity: entry.entity,
          entityId: entry.entityId,
          metadata: entry.metadata ? AuditService.sanitize(entry.metadata) : undefined,
          ip: entry.ip,
          userAgent: entry.userAgent?.slice(0, 512),
          requestId: entry.requestId,
        },
      });
    } catch (error) {
      this.logger.error({ err: error, action: entry.action }, 'Falha ao gravar auditoria');
    }
  }

  /** Remove recursivamente qualquer chave sensivel do metadata. */
  static sanitize(value: Prisma.InputJsonValue): Prisma.InputJsonValue {
    if (Array.isArray(value)) {
      return value.map((v) => AuditService.sanitize(v as Prisma.InputJsonValue));
    }
    if (value !== null && typeof value === 'object') {
      const out: Record<string, unknown> = {};
      for (const [key, v] of Object.entries(value)) {
        if (FORBIDDEN_KEYS.has(key)) continue;
        out[key] = AuditService.sanitize(v as Prisma.InputJsonValue);
      }
      return out as Prisma.InputJsonValue;
    }
    return value;
  }
}
