import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/paged_list_view.dart';
import '../data/channel_providers.dart';
import '../domain/channel_post.dart';

/// Canal dos Pastores: feed institucional (nao e rede social).
class ChannelFeedScreen extends ConsumerStatefulWidget {
  const ChannelFeedScreen({super.key});

  @override
  ConsumerState<ChannelFeedScreen> createState() => _ChannelFeedScreenState();
}

class _ChannelFeedScreenState extends ConsumerState<ChannelFeedScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(channelQueryProvider.notifier)
          .update((q) => q.copyWith(search: value.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final query = ref.watch(channelQueryProvider);
    final notifier = ref.read(channelQueryProvider.notifier);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Canal',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Comunicados e conteúdos da liderança',
                    style: TextStyle(color: AppColors.mutedInk),
                  ),
                  const SizedBox(height: AppTokens.space16),
                  TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar publicação',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          avatar: const Icon(Icons.push_pin_outlined, size: 18),
                          label: const Text('Fixados'),
                          selected: query.pinnedOnly,
                          onSelected: (v) =>
                              notifier.update((q) => q.copyWith(pinnedOnly: v)),
                        ),
                        const SizedBox(width: AppTokens.space8),
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: query.type == null,
                          onSelected: (_) => notifier.update(
                            (q) => q.copyWith(type: () => null),
                          ),
                        ),
                        for (final type in ChannelPostType.values) ...[
                          const SizedBox(width: AppTokens.space8),
                          ChoiceChip(
                            avatar: Icon(type.icon, size: 18),
                            label: Text(type.label),
                            selected: query.type == type.apiValue,
                            onSelected: (_) => notifier.update(
                              (q) => q.copyWith(type: () => type.apiValue),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PagedListView(
                value: ref.watch(channelFeedProvider),
                padding: EdgeInsets.fromLTRB(
                  padding,
                  AppTokens.space16,
                  padding,
                  AppTokens.space32,
                ),
                spacing: AppTokens.space12,
                onLoadMore: () =>
                    ref.read(channelFeedProvider.notifier).loadMore(),
                onRetry: () => ref.invalidate(channelFeedProvider),
                onRefresh: () async => ref.invalidate(channelFeedProvider),
                empty: InlineEmpty(
                  icon: query.hasFilters
                      ? Icons.filter_alt_off_outlined
                      : Icons.campaign_outlined,
                  message: query.hasFilters
                      ? 'Nenhuma publicação com esses filtros.'
                      : 'Nenhuma publicação por enquanto.',
                  action: query.hasFilters
                      ? TextButton(
                          onPressed: () {
                            _search.clear();
                            notifier.set(const ChannelQuery());
                          },
                          child: const Text('Limpar filtros'),
                        )
                      : null,
                ),
                itemBuilder: (context, post) => ChannelPostCard(
                  post: post,
                  onTap: () => context.go('/channel/${post.id}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChannelPostCard extends StatelessWidget {
  const ChannelPostCard({super.key, required this.post, required this.onTap});

  final ChannelPostSummary post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (post.coverUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTokens.radius16),
              ),
              child: Image.network(
                post.coverUrl!,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(post.type.icon, size: 16, color: post.type.color),
                    const SizedBox(width: 6),
                    Text(
                      post.type.label,
                      style: TextStyle(
                        color: post.type.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    if (post.isPinned) ...[
                      const SizedBox(width: AppTokens.space8),
                      const Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: AppColors.mutedInk,
                      ),
                    ],
                    const Spacer(),
                    if (!post.isRead)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppTokens.pill),
                        ),
                        child: const Text(
                          'Novo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTokens.space8),
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                if (post.summary != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    post.summary!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: AppTokens.space12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          ?post.authorName,
                          if (post.publishedAt != null)
                            Formatters.relativeDateTime(post.publishedAt!),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (post.needsAck)
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.assignment_turned_in_outlined,
                            size: 14,
                            color: AppColors.accent,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Requer confirmação',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
