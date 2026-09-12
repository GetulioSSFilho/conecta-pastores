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
import '../../../core/widgets/person_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../churches/data/church_options_provider.dart';
import '../../pastors/domain/pastor_status.dart';
import '../../pastors/presentation/widgets/pastor_list_tile.dart';
import '../data/network_providers.dart';
import '../domain/network_node.dart';

/// Minha Rede: todos os pastores sob responsabilidade do usuario.
///
/// Lista (paginada, filtrada e ordenada no servidor) ou arvore da hierarquia.
class MyNetworkScreen extends ConsumerStatefulWidget {
  const MyNetworkScreen({super.key});

  @override
  ConsumerState<MyNetworkScreen> createState() => _MyNetworkScreenState();
}

class _MyNetworkScreenState extends ConsumerState<MyNetworkScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _treeView = false;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    // Filtros vindos da URL sao aplicados apos o primeiro frame
    // (Riverpod nao permite alterar providers durante o build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final params = GoRouterState.of(context).uri.queryParameters;
      ref.read(networkQueryProvider.notifier).set(NetworkQuery.fromUrl(params));
      _treeView = params['view'] == 'tree';
      setState(() => _ready = true);
    });
  }

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
          .read(networkQueryProvider.notifier)
          .update((q) => q.copyWith(search: value.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    final padding = size.pagePadding;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
              child: _Header(
                treeView: _treeView,
                onToggleView: (tree) => setState(() => _treeView = tree),
              ),
            ),
            if (!_treeView)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  AppTokens.space16,
                  padding,
                  0,
                ),
                child: _Filters(search: _search, onSearch: _onSearch),
              ),
            Expanded(
              child: !_ready
                  ? const SizedBox.shrink()
                  : _treeView
                  ? _NetworkTree(padding: padding)
                  : _NetworkList(padding: padding),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.treeView, required this.onToggleView});

  final bool treeView;
  final ValueChanged<bool> onToggleView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(networkSummaryProvider).value;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Minha Rede',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                summary == null
                    ? 'Pastores sob sua responsabilidade'
                    : [
                        Formatters.count(summary.total, 'pastor', 'pastores'),
                        Formatters.count(summary.direct, 'direto', 'diretos'),
                        if (summary.overdue30 > 0)
                          '${summary.overdue30} há mais de 30 dias',
                        if (summary.neverCared > 0)
                          Formatters.count(
                            summary.neverCared,
                            'nunca acompanhado',
                            'nunca acompanhados',
                          ),
                      ].join(' · '),
                style: const TextStyle(color: AppColors.mutedInk),
              ),
            ],
          ),
        ),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.view_list_rounded),
              tooltip: 'Lista',
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.account_tree_outlined),
              tooltip: 'Árvore',
            ),
          ],
          selected: {treeView},
          onSelectionChanged: (s) => onToggleView(s.first),
        ),
      ],
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.search, required this.onSearch});

  final TextEditingController search;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(networkQueryProvider);
    final notifier = ref.read(networkQueryProvider.notifier);
    final churches =
        ref.watch(scopedChurchOptionsProvider).value ?? const <ChurchOption>[];
    String? churchLabel() {
      for (final c in churches) {
        if (c.id == query.churchId) return c.name;
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: search,
          onChanged: onSearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar por nome ou e-mail',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    onPressed: () {
                      search.clear();
                      onSearch('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: AppTokens.space12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (filter, label) in [
                (CareFilter.all, 'Todos'),
                (CareFilter.overdue30, 'Há mais de 30 dias'),
                (CareFilter.never, 'Nunca acompanhados'),
              ]) ...[
                ChoiceChip(
                  label: Text(label),
                  selected: query.care == filter,
                  onSelected: (_) => notifier.update(
                    (q) => q.copyWith(
                      care: filter,
                      sort: filter == CareFilter.all
                          ? q.sort
                          : NetworkSort.longestWithoutCare,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space8),
              ],
              _MenuChip<String?>(
                icon: Icons.verified_user_outlined,
                label: query.status == null
                    ? 'Status'
                    : PastorStatus.fromApi(query.status).label,
                active: query.status != null,
                options: [
                  (null, 'Todos os status'),
                  for (final s in PastorStatus.values) (s.apiValue, s.label),
                ],
                onSelected: (value) =>
                    notifier.update((q) => q.copyWith(status: () => value)),
              ),
              const SizedBox(width: AppTokens.space8),
              if (churches.isNotEmpty) ...[
                _MenuChip<String?>(
                  icon: Icons.church_outlined,
                  label: churchLabel() ?? 'Igreja',
                  active: query.churchId != null,
                  options: [
                    (null, 'Todas as igrejas'),
                    for (final c in churches) (c.id, c.name),
                  ],
                  onSelected: (value) =>
                      notifier.update((q) => q.copyWith(churchId: () => value)),
                ),
                const SizedBox(width: AppTokens.space8),
              ],
              _MenuChip<NetworkSort>(
                icon: Icons.sort_rounded,
                label: query.sort.label,
                active: query.sort != NetworkSort.name,
                options: [for (final s in NetworkSort.values) (s, s.label)],
                onSelected: (value) =>
                    notifier.update((q) => q.copyWith(sort: value)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.options,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool active;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: label,
      position: PopupMenuPosition.under,
      onSelected: (i) => onSelected(options[i].$1),
      itemBuilder: (_) => [
        for (var i = 0; i < options.length; i++)
          PopupMenuItem(value: i, child: Text(options[i].$2)),
      ],
      child: Chip(
        avatar: Icon(
          icon,
          size: 18,
          color: active ? Colors.white : AppColors.primary,
        ),
        label: Text(
          label,
          style: TextStyle(color: active ? Colors.white : AppColors.ink),
        ),
        backgroundColor: active ? AppColors.primary : AppColors.surface,
        side: BorderSide(color: active ? AppColors.primary : AppColors.border),
      ),
    );
  }
}

class _NetworkList extends ConsumerWidget {
  const _NetworkList({required this.padding});

  final double padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCare = ref.watch(currentUserProvider)?.can('care.write') ?? false;
    final hasFilters = ref.watch(
      networkQueryProvider.select((q) => q.hasFilters),
    );

    return PagedListView(
      value: ref.watch(networkListProvider),
      padding: EdgeInsets.fromLTRB(
        padding,
        AppTokens.space16,
        padding,
        AppTokens.space32,
      ),
      onLoadMore: () => ref.read(networkListProvider.notifier).loadMore(),
      onRetry: () => ref.invalidate(networkListProvider),
      onRefresh: () async {
        ref
          ..invalidate(networkListProvider)
          ..invalidate(networkSummaryProvider);
      },
      empty: InlineEmpty(
        icon: hasFilters
            ? Icons.filter_alt_off_outlined
            : Icons.groups_2_outlined,
        message: hasFilters
            ? 'Nenhum pastor encontrado com esses filtros.'
            : 'Ainda não há pastores na sua rede.\nPeça à administração para vincular pastores a você.',
        action: hasFilters
            ? TextButton(
                onPressed: () => ref
                    .read(networkQueryProvider.notifier)
                    .set(const NetworkQuery()),
                child: const Text('Limpar filtros'),
              )
            : null,
      ),
      itemBuilder: (context, pastor) => PastorListTile(
        pastor: pastor,
        showDepth: true,
        onTap: () => context.go('/pastors/${pastor.id}'),
        onRegisterCare: canCare
            ? () => context.go('/care/new?pastorId=${pastor.id}')
            : null,
      ),
    );
  }
}

class _NetworkTree extends ConsumerWidget {
  const _NetworkTree({required this.padding});

  final double padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        padding,
        AppTokens.space16,
        padding,
        AppTokens.space32,
      ),
      children: [
        AsyncValueView(
          value: ref.watch(networkTreeProvider),
          onRetry: () => ref.invalidate(networkTreeProvider),
          data: (root) => root == null || root.children.isEmpty
              ? const InlineEmpty(
                  icon: Icons.account_tree_outlined,
                  message:
                      'Ainda não há pastores abaixo de você na hierarquia.',
                )
              : AppCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTokens.space8,
                  ),
                  child: _TreeNode(node: root, initiallyExpanded: true),
                ),
        ),
      ],
    );
  }
}

class _TreeNode extends StatefulWidget {
  const _TreeNode({required this.node, this.initiallyExpanded = false});

  final NetworkNode node;
  final bool initiallyExpanded;

  @override
  State<_TreeNode> createState() => _TreeNodeState();
}

class _TreeNodeState extends State<_TreeNode> {
  late var _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final days = node.daysSinceLastCare;
    final isRoot = node.depth == 0;
    final careColor = node.lastCareAt == null || (days ?? 0) > 30
        ? AppColors.alert
        : AppColors.mutedInk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: isRoot ? null : () => context.go('/pastors/${node.id}'),
          child: Padding(
            padding: EdgeInsets.fromLTRB(8.0 + 24.0 * node.depth, 6, 12, 6),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: node.children.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: _expanded ? 'Recolher' : 'Expandir',
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                          icon: Icon(
                            _expanded
                                ? Icons.expand_more_rounded
                                : Icons.chevron_right_rounded,
                          ),
                        ),
                ),
                PersonAvatar(
                  name: node.pastoralName,
                  photoUrl: node.photoUrl,
                  size: isRoot ? 40 : 34,
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRoot
                            ? '${node.pastoralName} (você)'
                            : node.pastoralName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        [
                          if (node.churchName != null) node.churchName!,
                          if (node.children.isNotEmpty)
                            Formatters.count(
                              node.descendantCount,
                              'pessoa na rede',
                              'pessoas na rede',
                            ),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isRoot)
                  Text(
                    Formatters.careSince(
                      days: days,
                      neverCared: node.lastCareAt == null,
                    ),
                    style: TextStyle(
                      color: careColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_expanded)
          for (final child in node.children)
            _TreeNode(node: child, initiallyExpanded: child.depth < 1),
      ],
    );
  }
}
