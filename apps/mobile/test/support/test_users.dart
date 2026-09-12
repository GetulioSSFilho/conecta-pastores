import 'package:pastoral_app/features/auth/domain/auth_user.dart';

/// Permissoes espelham as roles do seed da API (apps/api/prisma/seed.ts).
const pastorPermissions = {
  'pastor.read',
  'church.read',
  'geography.read',
  'network.read',
  'channel.read',
  'request.read',
  'request.write',
  'event.read',
  'document.read',
  'credential.read',
  'training.read',
  'training.enroll',
};

const supervisorPermissions = {
  'pastor.read',
  'church.read',
  'geography.read',
  'network.read',
  'care.read',
  'care.write',
  'care.read_restricted',
  'channel.read',
  'request.read',
  'request.write',
  'request.assign',
  'event.read',
  'event.write',
  'document.read',
  'credential.read',
  'training.read',
  'training.enroll',
  'report.read',
};

AuthUser testUser({
  Set<String> permissions = pastorPermissions,
  String firstName = 'Joao',
  String? pastorId = 'pastor-1',
  List<String> roles = const ['PASTOR'],
  bool mustChangePassword = false,
}) => AuthUser(
  id: 'user-1',
  email: 'teste@pastoral.dev',
  firstName: firstName,
  lastName: 'Silva',
  locale: 'pt-BR',
  timezone: 'America/Sao_Paulo',
  roles: roles,
  permissions: permissions,
  pastorId: pastorId,
  mustChangePassword: mustChangePassword,
);
