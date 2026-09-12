/**
 * Catalogo unico de permissoes.
 * Formato: <recurso>.<acao>. Seed cria a tabela a partir daqui.
 */
export const PERMISSIONS = {
  // Pastores
  PASTOR_READ: 'pastor.read',
  PASTOR_WRITE: 'pastor.write',
  PASTOR_DELETE: 'pastor.delete',
  PASTOR_READ_ADMIN_NOTES: 'pastor.read_admin_notes',

  // Igrejas / geografia
  CHURCH_READ: 'church.read',
  CHURCH_WRITE: 'church.write',
  CHURCH_DELETE: 'church.delete',
  GEOGRAPHY_READ: 'geography.read',
  GEOGRAPHY_WRITE: 'geography.write',

  // Hierarquia
  NETWORK_READ: 'network.read',
  NETWORK_WRITE: 'network.write',

  // Cuidado pastoral
  CARE_READ: 'care.read',
  CARE_WRITE: 'care.write',
  CARE_DELETE: 'care.delete',
  CARE_READ_RESTRICTED: 'care.read_restricted',
  CARE_READ_CONFIDENTIAL: 'care.read_confidential',

  // Canal
  CHANNEL_READ: 'channel.read',
  CHANNEL_WRITE: 'channel.write',
  CHANNEL_PUBLISH: 'channel.publish',
  CHANNEL_READ_STATS: 'channel.read_stats',

  // Solicitacoes
  REQUEST_READ: 'request.read',
  REQUEST_WRITE: 'request.write',
  REQUEST_ASSIGN: 'request.assign',
  REQUEST_RESOLVE: 'request.resolve',

  // Agenda
  EVENT_READ: 'event.read',
  EVENT_WRITE: 'event.write',

  // Documentos
  DOCUMENT_READ: 'document.read',
  DOCUMENT_WRITE: 'document.write',
  DOCUMENT_DELETE: 'document.delete',

  // Credenciais
  CREDENTIAL_READ: 'credential.read',
  CREDENTIAL_WRITE: 'credential.write',
  CREDENTIAL_REVOKE: 'credential.revoke',

  // Formacao
  TRAINING_READ: 'training.read',
  TRAINING_WRITE: 'training.write',
  TRAINING_ENROLL: 'training.enroll',
  TRAINING_MANAGE_ENROLLMENTS: 'training.manage_enrollments',

  // Relatorios / dashboards
  REPORT_READ: 'report.read',
  REPORT_READ_GLOBAL: 'report.read_global',
  REPORT_EXPORT: 'report.export',

  // Administracao
  USER_READ: 'user.read',
  USER_WRITE: 'user.write',
  ROLE_MANAGE: 'role.manage',
  SCOPE_MANAGE: 'scope.manage',
  AUDIT_READ: 'audit.read',
  SETTINGS_MANAGE: 'settings.manage',
} as const;

export type PermissionKey = (typeof PERMISSIONS)[keyof typeof PERMISSIONS];

export const ALL_PERMISSIONS: PermissionKey[] = Object.values(PERMISSIONS);

export function splitPermission(key: PermissionKey): { resource: string; action: string } {
  const [resource, action] = key.split('.');
  return { resource, action };
}

/** Roles de sistema criadas pelo seed. */
export const SYSTEM_ROLES = {
  GLOBAL_ADMIN: 'GLOBAL_ADMIN',
  NATIONAL_LEADER: 'NATIONAL_LEADER',
  REGIONAL_LEADER: 'REGIONAL_LEADER',
  SUPERVISOR: 'SUPERVISOR',
  PASTOR: 'PASTOR',
  SECRETARY: 'SECRETARY',
} as const;

export type SystemRoleKey = (typeof SYSTEM_ROLES)[keyof typeof SYSTEM_ROLES];
