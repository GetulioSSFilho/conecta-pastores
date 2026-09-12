import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paged_controller.dart';
import '../../../core/api/paginated.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/training_models.dart';

/// Filtros do catalogo de formacao.
class TrainingQuery {
  const TrainingQuery({this.kind, this.onlyMandatory = false});

  final TrainingKind? kind;
  final bool onlyMandatory;

  bool get hasFilters => kind != null || onlyMandatory;

  TrainingQuery copyWith({TrainingKind? Function()? kind, bool? onlyMandatory}) => TrainingQuery(
    kind: kind != null ? kind() : this.kind,
    onlyMandatory: onlyMandatory ?? this.onlyMandatory,
  );

  Map<String, dynamic> toApi(int page) => {
    'page': page,
    'pageSize': 25,
    'kind': kind?.apiValue,
    'isMandatory': onlyMandatory ? true : null,
  };
}

class TrainingQueryNotifier extends Notifier<TrainingQuery> {
  @override
  TrainingQuery build() => const TrainingQuery();

  void set(TrainingQuery query) => state = query;
  void update(TrainingQuery Function(TrainingQuery) change) => state = change(state);
}

final trainingQueryProvider =
    NotifierProvider.autoDispose<TrainingQueryNotifier, TrainingQuery>(TrainingQueryNotifier.new);

class TrainingCatalogController extends PagedController<Training> {
  @override
  Future<PagedResult<Training>> build() {
    ref.watch(trainingQueryProvider);
    return super.build();
  }

  @override
  Future<Paginated<Training>> fetchPage(int page) async {
    final json = await ref
        .read(apiClientProvider)
        .getJson('/training/catalog', query: ref.read(trainingQueryProvider).toApi(page));
    return Paginated.fromJson(json, Training.fromJson);
  }
}

final trainingCatalogProvider =
    AsyncNotifierProvider.autoDispose<TrainingCatalogController, PagedResult<Training>>(
      TrainingCatalogController.new,
    );

/// Matriculas do proprio usuario (vazio quando ele nao e pastor).
final myEnrollmentsProvider = FutureProvider.autoDispose<List<TrainingEnrollment>>((ref) async {
  final pastorId = ref.watch(currentUserProvider)?.pastorId;
  if (pastorId == null) return const [];
  final json = await ref
      .watch(apiClientProvider)
      .getJson('/training/enrollments', query: {'pastorId': pastorId, 'pageSize': 50});
  return Paginated.fromJson(json, TrainingEnrollment.fromJson).items.toList()
    ..sort((a, b) => a.status.index.compareTo(b.status.index));
});

final trainingDetailProvider = FutureProvider.autoDispose.family<TrainingDetail, String>((
  ref,
  id,
) async {
  final json = await ref.watch(apiClientProvider).getJson('/training/$id');
  return TrainingDetail.fromJson(json);
});

/// Acoes de matricula e de progresso. A API valida permissao e escopo.
class TrainingActions {
  const TrainingActions(this._ref);

  final Ref _ref;

  Future<void> enroll(String trainingId) async {
    await _ref.read(apiClientProvider).post('/training/enroll', body: {'trainingId': trainingId});
    _ref.invalidate(trainingDetailProvider(trainingId));
    _ref.invalidate(myEnrollmentsProvider);
    _ref.invalidate(trainingCatalogProvider);
  }

  Future<void> markModule({
    required String trainingId,
    required String enrollmentId,
    required String moduleId,
    required bool completed,
  }) async {
    await _ref
        .read(apiClientProvider)
        .put(
          '/training/enrollments/$enrollmentId/progress',
          body: {'moduleId': moduleId, 'completed': completed},
        );
    _ref.invalidate(trainingDetailProvider(trainingId));
    _ref.invalidate(myEnrollmentsProvider);
  }
}

final trainingActionsProvider = Provider<TrainingActions>(TrainingActions.new);
