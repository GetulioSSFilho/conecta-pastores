import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paged_controller.dart';
import '../../../core/api/paginated.dart';
import '../../network/domain/network_member.dart';

enum PastorSort {
  name('pastoralName', 'asc', 'Nome'),
  newest('createdAt', 'desc', 'Cadastrados recentemente'),
  longestWithoutCare('lastCareAt', 'asc', 'Mais tempo sem acompanhamento');

  const PastorSort(this.field, this.order, this.label);

  final String field;
  final String order;
  final String label;
}

/// Filtros do diretorio. Aplicados no servidor, sempre dentro do escopo do usuario.
class PastorQuery {
  const PastorQuery({
    this.search = '',
    this.status,
    this.countryId,
    this.regionId,
    this.churchId,
    this.sort = PastorSort.name,
  });

  final String search;
  final String? status;
  final String? countryId;
  final String? regionId;
  final String? churchId;
  final PastorSort sort;

  bool get hasFilters =>
      search.isNotEmpty ||
      status != null ||
      countryId != null ||
      regionId != null ||
      churchId != null;

  PastorQuery copyWith({
    String? search,
    String? Function()? status,
    String? Function()? countryId,
    String? Function()? regionId,
    String? Function()? churchId,
    PastorSort? sort,
  }) => PastorQuery(
    search: search ?? this.search,
    status: status != null ? status() : this.status,
    countryId: countryId != null ? countryId() : this.countryId,
    regionId: regionId != null ? regionId() : this.regionId,
    churchId: churchId != null ? churchId() : this.churchId,
    sort: sort ?? this.sort,
  );

  Map<String, dynamic> toApi(int page) => {
    'page': page,
    'pageSize': 25,
    'search': search,
    'status': status,
    'countryId': countryId,
    'regionId': regionId,
    'churchId': churchId,
    'sortBy': sort.field,
    'sortOrder': sort.order,
  };

  static PastorQuery fromUrl(Map<String, String> params) => PastorQuery(
    search: params['search'] ?? '',
    status: params['status'],
    countryId: params['countryId'],
    regionId: params['regionId'],
    churchId: params['churchId'],
    sort: PastorSort.values.firstWhere(
      (s) => s.field == params['sortBy'],
      orElse: () => PastorSort.name,
    ),
  );
}

class PastorQueryNotifier extends Notifier<PastorQuery> {
  @override
  PastorQuery build() => const PastorQuery();

  void set(PastorQuery query) => state = query;
  void update(PastorQuery Function(PastorQuery) change) =>
      state = change(state);
}

final pastorQueryProvider =
    NotifierProvider.autoDispose<PastorQueryNotifier, PastorQuery>(
      PastorQueryNotifier.new,
    );

class PastorDirectoryController extends PagedController<NetworkMember> {
  @override
  Future<PagedResult<NetworkMember>> build() {
    ref.watch(pastorQueryProvider);
    return super.build();
  }

  @override
  Future<Paginated<NetworkMember>> fetchPage(int page) async {
    final json = await ref
        .read(apiClientProvider)
        .getJson('/pastors', query: ref.read(pastorQueryProvider).toApi(page));
    return Paginated.fromJson(json, NetworkMember.fromJson);
  }
}

final pastorDirectoryProvider =
    AsyncNotifierProvider.autoDispose<
      PastorDirectoryController,
      PagedResult<NetworkMember>
    >(PastorDirectoryController.new);
