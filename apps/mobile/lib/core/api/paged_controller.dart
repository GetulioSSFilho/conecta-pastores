import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'paginated.dart';

/// Estado de uma lista paginada no servidor com "carregar mais".
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.total,
    required this.hasNext,
    this.loadingMore = false,
    this.loadMoreError,
  });

  factory PagedResult.first(Paginated<T> page) => PagedResult(
    items: page.items,
    page: page.page,
    total: page.total,
    hasNext: page.hasNext,
  );

  final List<T> items;
  final int page;
  final int total;
  final bool hasNext;
  final bool loadingMore;
  final Object? loadMoreError;

  PagedResult<T> copyWith({
    List<T>? items,
    int? page,
    int? total,
    bool? hasNext,
    bool? loadingMore,
    Object? loadMoreError,
    bool clearError = false,
  }) => PagedResult(
    items: items ?? this.items,
    page: page ?? this.page,
    total: total ?? this.total,
    hasNext: hasNext ?? this.hasNext,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: clearError ? null : loadMoreError ?? this.loadMoreError,
  );
}

/// Base para listas paginadas: a primeira pagina vem no `build`, as demais em [loadMore].
///
/// Subclasses observam o provider de filtros no `build` (refaz a busca quando
/// o filtro muda) e leem o filtro com `ref.read` em [fetchPage].
abstract class PagedController<T> extends AsyncNotifier<PagedResult<T>> {
  Future<Paginated<T>> fetchPage(int page);

  @override
  Future<PagedResult<T>> build() async => PagedResult.first(await fetchPage(1));

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNext || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true, clearError: true));
    try {
      final next = await fetchPage(current.page + 1);
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next.items],
          page: next.page,
          total: next.total,
          hasNext: next.hasNext,
          loadingMore: false,
          clearError: true,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreError: error),
      );
    }
  }
}
