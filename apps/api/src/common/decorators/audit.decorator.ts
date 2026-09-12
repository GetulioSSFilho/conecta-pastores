import { SetMetadata } from '@nestjs/common';
import type { AuditAction } from '@prisma/client';

export const AUDIT_KEY = 'auditMeta';

export interface AuditMeta {
  action: AuditAction;
  entity: string;
  /** Nome do param de rota que carrega o id da entidade. */
  idParam?: string;
}

/** Marca a rota para registro automatico em AuditLog. */
export const Audited = (meta: AuditMeta) => SetMetadata(AUDIT_KEY, meta);
