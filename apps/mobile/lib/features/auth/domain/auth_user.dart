/// Usuario autenticado, como devolvido por `/auth/login` e `/auth/me`.
///
/// `permissions` serve APENAS para esconder o que o usuario certamente nao pode
/// usar (UX). A autorizacao real acontece no servidor em toda requisicao.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.locale,
    required this.timezone,
    required this.roles,
    required this.permissions,
    this.avatarUrl,
    this.pastorId,
    this.mustChangePassword = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    locale: json['locale'] as String? ?? 'pt-BR',
    timezone: json['timezone'] as String? ?? 'America/Sao_Paulo',
    pastorId: json['pastorId'] as String?,
    roles: (json['roles'] as List? ?? const []).cast<String>(),
    permissions: {...(json['permissions'] as List? ?? const []).cast<String>()},
    mustChangePassword: json['mustChangePassword'] as bool? ?? false,
  );

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String locale;
  final String timezone;
  final String? pastorId;
  final List<String> roles;
  final Set<String> permissions;
  final bool mustChangePassword;

  String get displayName => '$firstName $lastName'.trim();

  String get initials {
    final parts = displayName.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
        .toUpperCase();
  }

  bool can(String permission) => permissions.contains(permission);

  bool canAny(Iterable<String> keys) => keys.any(permissions.contains);

  /// Tem responsabilidade sobre outros pastores (ve dashboard de lideranca).
  bool get isLeader => can('care.write') || can('report.read');

  AuthUser mergeMe(Map<String, dynamic> me) => AuthUser.fromJson({
    ...toJson(),
    ...me,
    'avatarUrl': me['avatarUrl'] ?? avatarUrl,
    'mustChangePassword': me['mustChangePassword'] ?? mustChangePassword,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'avatarUrl': avatarUrl,
    'locale': locale,
    'timezone': timezone,
    'pastorId': pastorId,
    'roles': roles,
    'permissions': permissions.toList(),
    'mustChangePassword': mustChangePassword,
  };
}
