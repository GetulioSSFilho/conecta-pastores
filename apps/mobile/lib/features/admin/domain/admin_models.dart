import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Situacao da conta de acesso (UserStatus da API).
enum AccountStatus {
  active('ACTIVE', 'Ativo', AppColors.success),
  invited('INVITED', 'Convidado', AppColors.accent),
  suspended('SUSPENDED', 'Suspenso', AppColors.alert),
  disabled('DISABLED', 'Desativado', AppColors.neutral);

  const AccountStatus(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  static AccountStatus fromApi(String? value) => AccountStatus.values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => AccountStatus.disabled,
  );
}

/// Usuario administrativo (`GET /users`).
class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.mustChangePassword,
    required this.roles,
    this.lastLoginAt,
    this.pastorId,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id'] as String,
    email: json['email'] as String? ?? '',
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    status: AccountStatus.fromApi(json['status'] as String?),
    mustChangePassword: json['mustChangePassword'] == true,
    roles: (json['roles'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(RoleRef.fromJson)
        .toList(),
    lastLoginAt: json['lastLoginAt'] is String
        ? DateTime.tryParse(json['lastLoginAt'] as String)
        : null,
    pastorId: json['pastorId'] as String?,
  );

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final AccountStatus status;
  final bool mustChangePassword;
  final List<RoleRef> roles;
  final DateTime? lastLoginAt;
  final String? pastorId;

  String get fullName => '$firstName $lastName'.trim();
}

class RoleRef {
  const RoleRef({required this.key, required this.name});

  factory RoleRef.fromJson(Map<String, dynamic> json) =>
      RoleRef(key: json['key'] as String? ?? '', name: json['name'] as String? ?? '');

  final String key;
  final String name;
}

/// Papel com suas permissoes (`GET /admin/roles`).
class AdminRole {
  const AdminRole({
    required this.id,
    required this.key,
    required this.name,
    required this.isSystem,
    required this.rank,
    required this.permissions,
    this.description,
  });

  factory AdminRole.fromJson(Map<String, dynamic> json) => AdminRole(
    id: json['id'] as String,
    key: json['key'] as String? ?? '',
    name: json['name'] as String? ?? '',
    isSystem: json['isSystem'] == true,
    rank: (json['rank'] as num?)?.toInt() ?? 0,
    description: json['description'] as String?,
    permissions: (json['permissions'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map((p) => p['key'] as String? ?? '')
        .where((key) => key.isNotEmpty)
        .toList()
      ..sort(),
  );

  final String id;
  final String key;
  final String name;
  final bool isSystem;
  final int rank;
  final String? description;
  final List<String> permissions;
}

/// Registro de auditoria (`GET /admin/audit`).
///
/// Nunca contem senha nem segredo: a API grava apenas quem, o que e quando.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.entity,
    required this.createdAt,
    this.entityId,
    this.authorName,
    this.authorEmail,
    this.ip,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>();
    final name = user == null
        ? null
        : '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    return AuditEntry(
      id: json['id'] as String,
      action: json['action'] as String? ?? '',
      entity: json['entity'] as String? ?? '',
      entityId: json['entityId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      authorName: (name == null || name.isEmpty) ? null : name,
      authorEmail: user?['email'] as String?,
      ip: json['ip'] as String?,
    );
  }

  final String id;
  final String action;
  final String entity;
  final String? entityId;
  final DateTime createdAt;
  final String? authorName;
  final String? authorEmail;
  final String? ip;

  /// Rótulo em português para cada AuditAction; ações novas caem no próprio
  /// código, sem quebrar a tela.
  String get actionLabel => switch (action) {
    'CREATE' => 'Criou',
    'UPDATE' => 'Atualizou',
    'DELETE' => 'Removeu',
    'RESTORE' => 'Restaurou',
    'LOGIN' => 'Entrou',
    'LOGIN_FAILED' => 'Tentativa de acesso falhou',
    'LOGOUT' => 'Saiu',
    'TOKEN_REFRESH' => 'Renovou a sessão',
    'PASSWORD_CHANGE' => 'Trocou a senha',
    'PASSWORD_RESET_REQUEST' => 'Pediu redefinição de senha',
    'PASSWORD_RESET' => 'Redefiniu a senha',
    'READ_CONFIDENTIAL' => 'Leu registro confidencial',
    'PERMISSION_CHANGE' => 'Alterou permissões',
    'ROLE_CHANGE' => 'Alterou papéis',
    'SUPERVISOR_CHANGE' => 'Alterou supervisão',
    'EXPORT' => 'Exportou',
    'ACCESS_DENIED' => 'Acesso negado',
    _ => action,
  };

  Color get actionColor => switch (action) {
    'DELETE' || 'ACCESS_DENIED' || 'LOGIN_FAILED' => AppColors.alert,
    'READ_CONFIDENTIAL' ||
    'PERMISSION_CHANGE' ||
    'ROLE_CHANGE' ||
    'SUPERVISOR_CHANGE' ||
    'PASSWORD_RESET' ||
    'PASSWORD_CHANGE' => AppColors.accent,
    'CREATE' || 'RESTORE' => AppColors.success,
    _ => AppColors.neutral,
  };

  IconData get icon => switch (action) {
    'CREATE' => Icons.add_circle_outline_rounded,
    'UPDATE' => Icons.edit_outlined,
    'DELETE' => Icons.delete_outline_rounded,
    'LOGIN' => Icons.login_rounded,
    'LOGIN_FAILED' || 'ACCESS_DENIED' => Icons.block_rounded,
    'LOGOUT' => Icons.logout_rounded,
    'TOKEN_REFRESH' => Icons.autorenew_rounded,
    'ROLE_CHANGE' || 'SUPERVISOR_CHANGE' => Icons.swap_horiz_rounded,
    'READ_CONFIDENTIAL' => Icons.lock_outline_rounded,
    'PERMISSION_CHANGE' => Icons.admin_panel_settings_outlined,
    'PASSWORD_RESET' => Icons.key_outlined,
    _ => Icons.history_rounded,
  };
}
