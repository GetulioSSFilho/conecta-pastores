import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paged_controller.dart';
import '../../../core/api/paginated.dart';
import '../domain/admin_models.dart';

/// Filtro da lista de usuarios administrativos.
class UserQuery {
  const UserQuery({this.search = '', this.status, this.roleKey});

  final String search;
  final AccountStatus? status;
  final String? roleKey;

  bool get hasFilters => search.isNotEmpty || status != null || roleKey != null;

  UserQuery copyWith({
    String? search,
    AccountStatus? Function()? status,
    String? Function()? roleKey,
  }) => UserQuery(
    search: search ?? this.search,
    status: status != null ? status() : this.status,
    roleKey: roleKey != null ? roleKey() : this.roleKey,
  );

  Map<String, dynamic> toApi(int page) => {
    'page': page,
    'pageSize': 25,
    'search': search,
    'status': status?.apiValue,
    'roleKey': roleKey,
  };
}

class UserQueryNotifier extends Notifier<UserQuery> {
  @override
  UserQuery build() => const UserQuery();

  void set(UserQuery query) => state = query;
  void update(UserQuery Function(UserQuery) change) => state = change(state);
}

final userQueryProvider =
    NotifierProvider.autoDispose<UserQueryNotifier, UserQuery>(UserQueryNotifier.new);

class AdminUsersController extends PagedController<AdminUser> {
  @override
  Future<PagedResult<AdminUser>> build() {
    ref.watch(userQueryProvider);
    return super.build();
  }

  @override
  Future<Paginated<AdminUser>> fetchPage(int page) async {
    final json = await ref
        .read(apiClientProvider)
        .getJson('/users', query: ref.read(userQueryProvider).toApi(page));
    return Paginated.fromJson(json, AdminUser.fromJson);
  }
}

final adminUsersProvider =
    AsyncNotifierProvider.autoDispose<AdminUsersController, PagedResult<AdminUser>>(
      AdminUsersController.new,
    );

/// Papeis com suas permissoes. Exige `role.manage` - sem ela a API devolve 403.
final adminRolesProvider = FutureProvider.autoDispose<List<AdminRole>>((ref) async {
  final list = await ref.watch(apiClientProvider).getList('/admin/roles');
  return list.cast<Map<String, dynamic>>().map(AdminRole.fromJson).toList()
    ..sort((a, b) => b.rank.compareTo(a.rank));
});

/// Filtro da auditoria: por acao (CREATE, DELETE, LOGIN...).
class AuditFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? action) => state = action;
}

final auditFilterProvider = NotifierProvider.autoDispose<AuditFilter, String?>(AuditFilter.new);

class AuditController extends PagedController<AuditEntry> {
  @override
  Future<PagedResult<AuditEntry>> build() {
    ref.watch(auditFilterProvider);
    return super.build();
  }

  @override
  Future<Paginated<AuditEntry>> fetchPage(int page) async {
    final json = await ref
        .read(apiClientProvider)
        .getJson(
          '/admin/audit',
          query: {'page': page, 'pageSize': 25, 'action': ref.read(auditFilterProvider)},
        );
    return Paginated.fromJson(json, AuditEntry.fromJson);
  }
}

final auditProvider =
    AsyncNotifierProvider.autoDispose<AuditController, PagedResult<AuditEntry>>(
      AuditController.new,
    );
