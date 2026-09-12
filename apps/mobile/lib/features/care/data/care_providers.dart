import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paged_controller.dart';
import '../../../core/api/paginated.dart';
import '../../dashboard/data/dashboard_providers.dart';
import '../../network/data/network_providers.dart';
import '../domain/care_models.dart';

final careTypesProvider = FutureProvider<List<CareType>>((ref) async {
  final list = await ref.watch(apiClientProvider).getList('/care/types');
  return list.cast<Map<String, dynamic>>().map(CareType.fromJson).toList();
});

/// Filtros do historico de cuidado (aplicados no servidor).
class CareQuery {
  const CareQuery({
    this.search = '',
    this.pastorId,
    this.typeId,
    this.days = 90,
  });

  final String search;
  final String? pastorId;
  final String? typeId;

  /// Janela de tempo em dias (0 = sem limite).
  final int days;

  bool get hasFilters =>
      search.isNotEmpty || pastorId != null || typeId != null || days != 90;

  CareQuery copyWith({
    String? search,
    String? Function()? pastorId,
    String? Function()? typeId,
    int? days,
  }) => CareQuery(
    search: search ?? this.search,
    pastorId: pastorId != null ? pastorId() : this.pastorId,
    typeId: typeId != null ? typeId() : this.typeId,
    days: days ?? this.days,
  );

  Map<String, dynamic> toApi(int page) => {
    'page': page,
    'pageSize': 25,
    'search': search,
    'pastorId': pastorId,
    'typeId': typeId,
    if (days > 0) 'from': DateTime.now().subtract(Duration(days: days)).toUtc(),
    'sortOrder': 'desc',
  };
}

class CareQueryNotifier extends Notifier<CareQuery> {
  @override
  CareQuery build() => const CareQuery();

  void set(CareQuery query) => state = query;
  void update(CareQuery Function(CareQuery) change) => state = change(state);
}

final careQueryProvider =
    NotifierProvider.autoDispose<CareQueryNotifier, CareQuery>(
      CareQueryNotifier.new,
    );

class CareListController extends PagedController<CareRecord> {
  @override
  Future<PagedResult<CareRecord>> build() {
    ref.watch(careQueryProvider);
    return super.build();
  }

  @override
  Future<Paginated<CareRecord>> fetchPage(int page) async {
    final json = await ref
        .read(apiClientProvider)
        .getJson('/care', query: ref.read(careQueryProvider).toApi(page));
    return Paginated.fromJson(json, CareRecord.fromJson);
  }
}

final careListProvider =
    AsyncNotifierProvider.autoDispose<
      CareListController,
      PagedResult<CareRecord>
    >(CareListController.new);

/// Detalhe com anotacoes completas (a API audita leitura restrita/confidencial).
final careRecordProvider = FutureProvider.autoDispose
    .family<CareRecord, String>((ref, id) async {
      return CareRecord.fromJson(
        await ref.watch(apiClientProvider).getJson('/care/$id'),
      );
    });

/// Registra o acompanhamento e atualiza o que depende dele (rede, dashboard, perfil).
final createCareProvider = Provider<Future<void> Function(NewCare)>((ref) {
  return (NewCare care) async {
    await ref.read(apiClientProvider).post('/care', body: care.toApi());
    ref
      ..invalidate(careListProvider)
      ..invalidate(networkListProvider)
      ..invalidate(networkSummaryProvider)
      ..invalidate(leaderDashboardProvider)
      ..invalidate(attentionPastorsProvider)
      ..invalidate(careActivityProvider);
  };
});
