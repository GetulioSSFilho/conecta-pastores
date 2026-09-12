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
import '../../auth/application/auth_controller.dart';
import '../data/requests_providers.dart';
import '../domain/request_models.dart';

/// Central de solicitacoes: o pastor pede ajuda, a lideranca acompanha.
class RequestsListScreen extends ConsumerStatefulWidget {
  const RequestsListScreen({super.key});

  @override
  ConsumerState<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends ConsumerState<RequestsListScreen> {
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
          .read(requestQueryProvider.notifier)
          .update((q) => q.copyWith(search: value.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final query = ref.watch(requestQueryProvider);
    final notifier = ref.read(requestQueryProvider.notifier);
    final canCreate =
        ref.watch(currentUserProvider)?.can('request.write') ?? false;
    final total = ref.watch(requestsProvider).value?.total;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solicitações',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          total == null
                              ? 'Pedidos de apoio e atendimento'
                              : '$total ${total == 1 ? 'solicitação' : 'solicitações'}',
                          style: const TextStyle(color: AppColors.mutedInk),
                        ),
                      ],
                    ),
                  ),
                  if (canCreate)
                    FilledButton.icon(
                      onPressed: () => context.go('/requests/new'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nova solicitação'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                padding,
                AppTokens.space16,
                padding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por assunto',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Todas'),
                          selected: query.status == null,
                          onSelected: (_) => notifier.update(
                            (q) => q.copyWith(status: () => null),
                          ),
                        ),
                        for (final status in RequestStatusKind.values) ...[
                          const SizedBox(width: AppTokens.space8),
                          ChoiceChip(
                            label: Text(status.label),
                            selected: query.status == status,
                            onSelected: (_) => notifier.update(
                              (q) => q.copyWith(status: () => status),
                            ),
                          ),
                        ],
                        const SizedBox(width: AppTokens.space16),
                        for (final priority in [
                          RequestPriorityKind.urgent,
                          RequestPriorityKind.high,
                        ]) ...[
                          FilterChip(
                            avatar: Icon(
                              Icons.flag_outlined,
                              size: 18,
                              color: priority.color,
                            ),
                            label: Text(priority.label),
                            selected: query.priority == priority,
                            onSelected: (v) => notifier.update(
                              (q) => q.copyWith(
                                priority: () => v ? priority : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTokens.space8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PagedListView(
                value: ref.watch(requestsProvider),
                padding: EdgeInsets.fromLTRB(
                  padding,
                  AppTokens.space16,
                  padding,
                  AppTokens.space32,
                ),
                onLoadMore: () =>
                    ref.read(requestsProvider.notifier).loadMore(),
                onRetry: () => ref.invalidate(requestsProvider),
                onRefresh: () async => ref.invalidate(requestsProvider),
                empty: InlineEmpty(
                  icon: query.hasFilters
                      ? Icons.filter_alt_off_outlined
                      : Icons.support_agent_outlined,
                  message: query.hasFilters
                      ? 'Nenhuma solicitação com esses filtros.'
                      : 'Nenhuma solicitação por aqui.\nQuando precisar de apoio, abra uma solicitação.',
                  action: query.hasFilters
                      ? TextButton(
                          onPressed: () {
                            _search.clear();
                            notifier.set(const RequestQuery());
                          },
                          child: const Text('Limpar filtros'),
                        )
                      : null,
                ),
                itemBuilder: (context, request) =>
                    _RequestCard(request: request),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final RequestSummary request;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go('/requests/${request.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${request.number}',
                style: const TextStyle(
                  color: AppColors.mutedInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Text(
                  request.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              _Tag(label: request.status.label, color: request.status.color),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (request.priority != RequestPriorityKind.normal) ...[
                Icon(
                  Icons.flag_outlined,
                  size: 14,
                  color: request.priority.color,
                ),
                const SizedBox(width: 4),
                Text(
                  request.priority.label,
                  style: TextStyle(
                    color: request.priority.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
              ],
              Expanded(
                child: Text(
                  [
                    ?request.categoryName,
                    if (request.pastoralName != null)
                      'Pastor: ${request.pastoralName}',
                    request.assigneeName == null
                        ? 'Sem responsável'
                        : 'Com ${request.assigneeName}',
                    Formatters.relativeDateTime(request.createdAt),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTokens.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
