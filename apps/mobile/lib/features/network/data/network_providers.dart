import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paged_controller.dart';
import '../../../core/api/paginated.dart';
import '../domain/network_member.dart';
import '../domain/network_node.dart';

enum CareFilter { all, overdue30, never }

enum NetworkSort {
  name('pastoralName', 'asc', 'Nome'),
  longestWithoutCare('lastCareAt', 'asc', 'Mais tempo sem acompanhamento'),
  nextCare('nextCareAt', 'asc', 'Próximo acompanhamento');

  const NetworkSort(this.field, this.order, this.label);

  final String field;
  final String order;
  final String label;
}

/// Filtros da Minha Rede. Todos aplicados no servidor.
class NetworkQuery {
  const NetworkQuery({
    this.search = '',
    this.care = CareFilter.all,
    this.status,
    this.churchId,
    this.sort = NetworkSort.name,
  });

  final String search;
  final CareFilter care;
  final String? status;
  final String? churchId;
  final NetworkSort sort;

  bool get hasFilters =>
      search.isNotEmpty ||
      care != CareFilter.all ||
      status != null ||
      churchId != null;

  NetworkQuery copyWith({
    String? search,
    CareFilter? care,
    String? Function()? status,
    String? Function()? churchId,
    NetworkSort? sort,
  }) => NetworkQuery(
    search: search ?? this.search,
    care: care ?? this.care,
    status: status != null ? status() : this.status,
    churchId: churchId != null ? churchId() : this.churchId,
    sort: sort ?? this.sort,
  );

  Map<String, dynamic> toApi(int page) => {
    'page': page,
    'pageSize': 25,
    'search': search,
    'status': status,
    'churchId': churchId,
    if (care == CareFilter.overdue30) 'careOverdueDays': 30,
    if (care == CareFilter.never) 'neverCared': true,
    'sortBy': sort.field,
    'sortOrder': sort.order,
  };

  /// Filtros vindos de links (ex.: dashboard -> /network?careOverdueDays=30).
  static NetworkQuery fromUrl(Map<String, String> params) => NetworkQuery(
    care: params['neverCared'] == 'true'
        ? CareFilter.never
        : params.containsKey('careOverdueDays')
        ? CareFilter.overdue30
        : CareFilter.all,
    status: params['status'],
    churchId: params['churchId'],
    sort:
        params.containsKey('careOverdueDays') || params['neverCared'] == 'true'
        ? NetworkSort.longestWithoutCare
        : NetworkSort.name,
  );
}

class NetworkQueryNotifier extends Notifier<NetworkQuery> {
  @override
  NetworkQuery build() => const NetworkQuery();

  void set(NetworkQuery query) => state = query;
  void update(NetworkQuery Function(NetworkQuery) change) =>
      state = change(state);
}

final networkQueryProvider =
    NotifierProvider.autoDispose<NetworkQueryNotifier, NetworkQuery>(
      NetworkQueryNotifier.new,
    );

class NetworkListController extends PagedController<NetworkMember> {
  @override
  Future<PagedResult<NetworkMember>> build() {
    ref.watch(networkQueryProvider);
    return super.build();
  }

  @override
  Future<Paginated<NetworkMember>> fetchPage(int page) async {
    final query = ref.read(networkQueryProvider);
    final json = await ref
        .read(apiClientProvider)
        .getJson('/network', query: query.toApi(page));
    return Paginated.fromJson(json, NetworkMember.fromJson);
  }
}

final networkListProvider =
    AsyncNotifierProvider.autoDispose<
      NetworkListController,
      PagedResult<NetworkMember>
    >(NetworkListController.new);

final networkTreeProvider = FutureProvider.autoDispose<NetworkNode?>((
  ref,
) async {
  final json = await ref
      .watch(apiClientProvider)
      .getJson('/network/tree', query: {'maxDepth': 6});
  return json.isEmpty ? null : NetworkNode.fromJson(json);
});

class NetworkSummary {
  const NetworkSummary({
    required this.total,
    required this.direct,
    required this.neverCared,
    required this.overdue30,
  });

  final int total;
  final int direct;
  final int neverCared;
  final int overdue30;
}

final networkSummaryProvider = FutureProvider.autoDispose<NetworkSummary>((
  ref,
) async {
  final json = await ref.watch(apiClientProvider).getJson('/network/summary');
  int n(String key) => (json[key] as num?)?.toInt() ?? 0;
  return NetworkSummary(
    total: n('totalInNetwork'),
    direct: n('directReports'),
    neverCared: n('neverCared'),
    overdue30: n('careOverdue30Days'),
  );
});
