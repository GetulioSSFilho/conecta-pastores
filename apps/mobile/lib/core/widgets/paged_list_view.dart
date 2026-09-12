import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/paged_controller.dart';
import '../errors/failure_message.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'async_value_view.dart';
import 'skeleton.dart';

/// Lista com paginacao infinita, skeleton, vazio, erro e "carregar mais".
///
/// O cabecalho (busca/filtros) fica FORA desta lista, na tela: assim o campo de
/// busca nao perde foco quando a lista recarrega.
class PagedListView<T> extends StatelessWidget {
  const PagedListView({
    super.key,
    required this.value,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRetry,
    required this.empty,
    this.onRefresh,
    this.padding = const EdgeInsets.all(AppTokens.space16),
    this.spacing = AppTokens.space8,
  });

  final AsyncValue<PagedResult<T>> value;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final Widget empty;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final list = value.when(
      skipLoadingOnRefresh: true,
      loading: () => ListView(
        padding: padding,
        children: [
          for (var i = 0; i < 6; i++)
            Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: const _TileSkeleton(),
            ),
        ],
      ),
      error: (error, _) => ListView(
        padding: padding,
        children: [
          if (isForbidden(error))
            const NoAccessNotice()
          else
            InlineError(message: errorMessage(error), onRetry: onRetry),
        ],
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return ListView(padding: padding, children: [empty]);
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            final nearEnd = notification.metrics.extentAfter < 480;
            if (nearEnd &&
                page.hasNext &&
                !page.loadingMore &&
                page.loadMoreError == null) {
              onLoadMore();
            }
            return false;
          },
          child: ListView.builder(
            padding: padding,
            itemCount: page.items.length + 1,
            itemBuilder: (context, index) {
              if (index == page.items.length) {
                return _Footer(page: page, onLoadMore: onLoadMore);
              }
              return Padding(
                padding: EdgeInsets.only(bottom: spacing),
                child: itemBuilder(context, page.items[index]),
              );
            },
          ),
        );
      },
    );

    final refresh = onRefresh;
    return refresh == null
        ? list
        : RefreshIndicator(onRefresh: refresh, child: list);
  }
}

class _Footer<T> extends StatelessWidget {
  const _Footer({required this.page, required this.onLoadMore});

  final PagedResult<T> page;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (page.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AppTokens.space16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (page.loadMoreError != null) {
      return InlineError(
        message: errorMessage(page.loadMoreError!),
        onRetry: onLoadMore,
      );
    }
    if (page.hasNext) {
      // Fallback quando a lista nao rola (tela alta): carregar sob demanda.
      return Center(
        child: TextButton(
          onPressed: onLoadMore,
          child: const Text('Carregar mais'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space16),
      child: Text(
        page.total == 1 ? '1 registro' : '${page.total} registros',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
      ),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Skeleton(width: 44, height: 44, radius: 22),
          SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 180, height: 14),
                SizedBox(height: 8),
                Skeleton(width: 120, height: 11),
              ],
            ),
          ),
          Skeleton(width: 90, height: 12),
        ],
      ),
    );
  }
}
