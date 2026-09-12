import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paged_controller.dart';
import '../../../core/api/paginated.dart';
import '../domain/request_models.dart';

final requestCategoriesProvider = FutureProvider<List<RequestCategory>>((
  ref,
) async {
  final list = await ref
      .watch(apiClientProvider)
      .getList('/requests/categories');
  return list
      .cast<Map<String, dynamic>>()
      .map(RequestCategory.fromJson)
      .toList();
});

/// Filtros da central de solicitacoes (aplicados no servidor).
class RequestQuery {
  const RequestQuery({
    this.search = '',
    this.status,
    this.priority,
    this.pastorId,
  });

  final String search;
  final RequestStatusKind? status;
  final RequestPriorityKind? priority;
  final String? pastorId;

  bool get hasFilters =>
      search.isNotEmpty ||
      status != null ||
      priority != null ||
      pastorId != null;

  RequestQuery copyWith({
    String? search,
    RequestStatusKind? Function()? status,
    RequestPriorityKind? Function()? priority,
    String? Function()? pastorId,
  }) => RequestQuery(
    search: search ?? this.search,
    status: status != null ? status() : this.status,
    priority: priority != null ? priority() : this.priority,
    pastorId: pastorId != null ? pastorId() : this.pastorId,
  );

  Map<String, dynamic> toApi(int page) => {
    'page': page,
    'pageSize': 25,
    'search': search,
    'status': status?.apiValue,
    'priority': priority?.apiValue,
    'pastorId': pastorId,
  };
}

class RequestQueryNotifier extends Notifier<RequestQuery> {
  @override
  RequestQuery build() => const RequestQuery();

  void set(RequestQuery query) => state = query;
  void update(RequestQuery Function(RequestQuery) change) =>
      state = change(state);
}

final requestQueryProvider =
    NotifierProvider.autoDispose<RequestQueryNotifier, RequestQuery>(
      RequestQueryNotifier.new,
    );

class RequestsController extends PagedController<RequestSummary> {
  @override
  Future<PagedResult<RequestSummary>> build() {
    ref.watch(requestQueryProvider);
    return super.build();
  }

  @override
  Future<Paginated<RequestSummary>> fetchPage(int page) async {
    final json = await ref
        .read(apiClientProvider)
        .getJson(
          '/requests',
          query: ref.read(requestQueryProvider).toApi(page),
        );
    return Paginated.fromJson(json, RequestSummary.fromJson);
  }
}

final requestsProvider =
    AsyncNotifierProvider.autoDispose<
      RequestsController,
      PagedResult<RequestSummary>
    >(RequestsController.new);

final requestDetailProvider = FutureProvider.autoDispose
    .family<RequestDetail, String>((ref, id) async {
      return RequestDetail.fromJson(
        await ref.watch(apiClientProvider).getJson('/requests/$id'),
      );
    });

/// Acoes de escrita. Cada uma invalida o que precisa ser recarregado.
class RequestActions {
  const RequestActions(this._ref);

  final Ref _ref;

  Future<String> create({
    required String categoryId,
    required String subject,
    required String description,
    RequestPriorityKind priority = RequestPriorityKind.normal,
    String? pastorId,
  }) async {
    final created = await _ref
        .read(apiClientProvider)
        .post(
          '/requests',
          body: {
            'categoryId': categoryId,
            'subject': subject.trim(),
            'description': description.trim(),
            'priority': priority.apiValue,
            'pastorId': ?pastorId,
          },
        );
    _ref.invalidate(requestsProvider);
    return (created as Map?)?['id'] as String? ?? '';
  }

  Future<void> comment(
    String requestId,
    String message, {
    bool internal = false,
  }) async {
    await _ref
        .read(apiClientProvider)
        .post(
          '/requests/$requestId/comments',
          body: {'message': message.trim(), 'isInternal': internal},
        );
    _ref.invalidate(requestDetailProvider(requestId));
  }

  Future<void> changeStatus(
    String requestId,
    RequestStatusKind status, {
    String? resolution,
  }) async {
    await _ref
        .read(apiClientProvider)
        .put(
          '/requests/$requestId/status',
          body: {
            'status': status.apiValue,
            if (resolution != null && resolution.trim().isNotEmpty)
              'resolution': resolution.trim(),
          },
        );
    _ref
      ..invalidate(requestDetailProvider(requestId))
      ..invalidate(requestsProvider);
  }

  /// Assume o atendimento (sem `assigneeId` a API atribui ao proprio usuario).
  Future<void> assignToMe(String requestId) async {
    await _ref
        .read(apiClientProvider)
        .put('/requests/$requestId/assign', body: {});
    _ref
      ..invalidate(requestDetailProvider(requestId))
      ..invalidate(requestsProvider);
  }
}

final requestActionsProvider = Provider<RequestActions>(RequestActions.new);
