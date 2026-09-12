import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paged_controller.dart';
import '../../../core/api/paginated.dart';
import '../domain/church_models.dart';

/// Filtros da listagem de igrejas (aplicados no servidor, dentro do escopo).
class ChurchQuery {
  const ChurchQuery({this.search = '', this.countryId, this.status, this.type});

  final String search;
  final String? countryId;
  final ChurchStatus? status;
  final ChurchType? type;

  bool get hasFilters =>
      search.isNotEmpty || countryId != null || status != null || type != null;

  ChurchQuery copyWith({
    String? search,
    String? Function()? countryId,
    ChurchStatus? Function()? status,
    ChurchType? Function()? type,
  }) => ChurchQuery(
    search: search ?? this.search,
    countryId: countryId != null ? countryId() : this.countryId,
    status: status != null ? status() : this.status,
    type: type != null ? type() : this.type,
  );

  Map<String, dynamic> toApi(int page) => {
    'page': page,
    'pageSize': 25,
    'search': search,
    'countryId': countryId,
    'status': status?.apiValue,
    'type': type?.apiValue,
  };
}

class ChurchQueryNotifier extends Notifier<ChurchQuery> {
  @override
  ChurchQuery build() => const ChurchQuery();

  void set(ChurchQuery query) => state = query;
  void update(ChurchQuery Function(ChurchQuery) change) => state = change(state);
}

final churchQueryProvider =
    NotifierProvider.autoDispose<ChurchQueryNotifier, ChurchQuery>(ChurchQueryNotifier.new);

class ChurchesController extends PagedController<Church> {
  @override
  Future<PagedResult<Church>> build() {
    ref.watch(churchQueryProvider);
    return super.build();
  }

  @override
  Future<Paginated<Church>> fetchPage(int page) async {
    final json = await ref
        .read(apiClientProvider)
        .getJson('/churches', query: ref.read(churchQueryProvider).toApi(page));
    return Paginated.fromJson(json, Church.fromJson);
  }
}

final churchesProvider =
    AsyncNotifierProvider.autoDispose<ChurchesController, PagedResult<Church>>(
      ChurchesController.new,
    );

/// Paises visiveis para o usuario, usados no filtro.
/// Sem permissao de geografia a lista volta vazia e o filtro some.
final countriesProvider = FutureProvider.autoDispose<List<GeoPlace>>((ref) async {
  final list = await ref.watch(apiClientProvider).getList('/countries');
  return list.cast<Map<String, dynamic>>().map(GeoPlace.fromJson).toList();
});

final churchDetailProvider = FutureProvider.autoDispose.family<ChurchDetail, String>((
  ref,
  id,
) async {
  final json = await ref.watch(apiClientProvider).getJson('/churches/$id');
  return ChurchDetail.fromJson(json);
});

/// Pastores da igreja: a API cruza o escopo de igreja com o de pastor.
final churchPastorsProvider = FutureProvider.autoDispose.family<List<ChurchPastor>, String>((
  ref,
  id,
) async {
  final json = await ref
      .watch(apiClientProvider)
      .getJson('/churches/$id/pastors', query: {'pageSize': 50});
  return Paginated.fromJson(json, ChurchPastor.fromJson).items.toList();
});
