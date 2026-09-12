import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/paged_list_view.dart';
import '../../../core/widgets/searchable_select.dart';
import '../../auth/application/auth_controller.dart';
import '../../churches/data/church_options_provider.dart';
import '../../pastors/domain/pastor_status.dart';
import '../../pastors/presentation/widgets/pastor_list_tile.dart';
import '../data/network_providers.dart';

enum _TreeFilter { all, overdue, thisWeek }

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
  var _treeFilter = _TreeFilter.all;
  var _treeSearch = '';

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

  void _onTreeSearch(String value) =>
      setState(() => _treeSearch = value.trim().toLowerCase());

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
            if (_treeView)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  AppTokens.space16,
                  padding,
                  0,
                ),
                child: _TreeFilters(
                  search: _search,
                  value: _treeSearch,
                  filter: _treeFilter,
                  onSearch: _onTreeSearch,
                  onFilterChanged: (filter) =>
                      setState(() => _treeFilter = filter),
                ),
              ),
            Expanded(
              child: !_ready
                  ? const SizedBox.shrink()
                  : _treeView
                  ? _NetworkTree(
                      padding: padding,
                      filter: _treeFilter,
                      search: _treeSearch,
                    )
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
                    : treeView
                    ? Formatters.count(summary.total, 'pastor', 'pastores')
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
    return SearchableFilterButton<T>(
      icon: icon,
      label: label,
      active: active,
      options: [
        for (final option in options)
          SearchableMenuOption(value: option.$1, label: option.$2),
      ],
      onSelected: onSelected,
    );
  }
}

class _TreeFilters extends StatelessWidget {
  const _TreeFilters({
    required this.search,
    required this.value,
    required this.filter,
    required this.onSearch,
    required this.onFilterChanged,
  });

  final TextEditingController search;
  final String value;
  final _TreeFilter filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<_TreeFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: search,
          onChanged: onSearch,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar pastor...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: value.isEmpty
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
              for (final (item, label) in [
                (_TreeFilter.all, 'Todos'),
                (_TreeFilter.overdue, '> 30 dias'),
                (_TreeFilter.thisWeek, 'Esta semana'),
              ]) ...[
                ChoiceChip(
                  label: Text(label),
                  selected: filter == item,
                  onSelected: (_) => onFilterChanged(item),
                ),
                const SizedBox(width: AppTokens.space8),
              ],
            ],
          ),
        ),
      ],
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

class _NetworkTree extends StatelessWidget {
  const _NetworkTree({
    required this.padding,
    required this.filter,
    required this.search,
  });

  final double padding;
  final _TreeFilter filter;
  final String search;

  @override
  Widget build(BuildContext context) {
    final filterLabel = switch (filter) {
      _TreeFilter.all => null,
      _TreeFilter.overdue => 'Mais de 30 dias',
      _TreeFilter.thisWeek => 'Esta semana',
    };

    return ListView(
      padding: EdgeInsets.fromLTRB(
        padding,
        AppTokens.space16,
        padding,
        AppTokens.space32,
      ),
      children: [
        if (filterLabel != null || search.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.space12),
            child: Text(
              [
                if (filterLabel != null) 'Filtro: $filterLabel',
                if (search.isNotEmpty) 'Busca: $search',
              ].join(' · '),
              style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
            ),
          ),
        _TreeGraph(filter: filter),
        const SizedBox(height: AppTokens.space16),
        const _TreeLegend(),
      ],
    );
  }
}

/// Organograma visual da referência. É deliberadamente um exemplo local:
/// permite validar a composição antes de decidir o contrato persistido da
/// árvore real.
class _TreeGraph extends StatelessWidget {
  const _TreeGraph({required this.filter});

  final _TreeFilter filter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const branchWidth = 156.0;
        const leafWidth = 150.0;
        const branchGap = 28.0;
        const leafGap = 16.0;
        final groupWidth = leafWidth * 2 + leafGap;
        final minimumWidth = groupWidth * 2 + branchGap;
        final width = math.max(constraints.maxWidth, minimumWidth);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: 540,
            child: LayoutBuilder(
              builder: (context, graphConstraints) {
                const rootWidth = 176.0;
                const rootHeight = 128.0;
                const branchHeight = 118.0;
                const leafHeight = 132.0;
                const rootTop = 8.0;
                const branchTop = 184.0;
                const leafTop = 362.0;
                final leftGroup =
                    (graphConstraints.maxWidth - minimumWidth) / 2;
                final rightGroup = leftGroup + groupWidth + branchGap;
                final leftBranch = leftGroup + (groupWidth - branchWidth) / 2;
                final rightBranch = rightGroup + (groupWidth - branchWidth) / 2;
                final center = graphConstraints.maxWidth / 2;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _TreeConnectorPainter(
                          rootBottomCenter: Offset(
                            center,
                            rootTop + rootHeight,
                          ),
                          branchY: 160,
                          branchTopCenters: [
                            Offset(leftBranch + branchWidth / 2, branchTop),
                            Offset(rightBranch + branchWidth / 2, branchTop),
                          ],
                          branchBottomCenters: [
                            Offset(
                              leftBranch + branchWidth / 2,
                              branchTop + branchHeight,
                            ),
                            Offset(
                              rightBranch + branchWidth / 2,
                              branchTop + branchHeight,
                            ),
                          ],
                          leafTopCenters: [
                            [
                              Offset(leftGroup + leafWidth / 2, leafTop),
                              Offset(
                                leftGroup + leafWidth + leafGap + leafWidth / 2,
                                leafTop,
                              ),
                            ],
                            [
                              Offset(rightGroup + leafWidth / 2, leafTop),
                              Offset(
                                rightGroup +
                                    leafWidth +
                                    leafGap +
                                    leafWidth / 2,
                                leafTop,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: center - rootWidth / 2,
                      top: rootTop,
                      child: const _TreePersonCard(
                        width: rootWidth,
                        height: rootHeight,
                        name: 'Pr. Carlos Mendes',
                        detail: 'Líder regional · MG',
                        detailColor: AppColors.primary,
                        image: 'assets/images/pastor_carlos.png',
                        emphasized: true,
                      ),
                    ),
                    Positioned(
                      left: leftBranch,
                      top: branchTop,
                      child: const _TreePersonCard(
                        width: branchWidth,
                        height: branchHeight,
                        name: 'Pr. Paulo Ribeiro',
                        detail: 'Supervisor · RMBH',
                        detailColor: AppColors.primary,
                        image: 'assets/images/pastor_joao.png',
                      ),
                    ),
                    Positioned(
                      left: rightBranch,
                      top: branchTop,
                      child: const _TreePersonCard(
                        width: branchWidth,
                        height: branchHeight,
                        name: 'Pra. Renata Almeida',
                        detail: 'Supervisora · RMBH',
                        detailColor: AppColors.primary,
                        image: 'assets/images/pastora_ana.png',
                      ),
                    ),
                    Positioned(
                      left: leftGroup,
                      top: leafTop,
                      child: _TreePersonCard(
                        width: leafWidth,
                        height: leafHeight,
                        name: 'Pr. João Silva',
                        detail: filter == _TreeFilter.thisWeek
                            ? 'Próximo: 18/09'
                            : 'Último cuidado: 8 dias',
                        detailColor: AppColors.success,
                        image: 'assets/images/pastor_joao.png',
                      ),
                    ),
                    Positioned(
                      left: leftGroup + leafWidth + leafGap,
                      top: leafTop,
                      child: _TreePersonCard(
                        width: leafWidth,
                        height: leafHeight,
                        name: 'Pra. Ana Souza',
                        detail: filter == _TreeFilter.thisWeek
                            ? 'Próximo: 20/09'
                            : 'Último cuidado: 12 dias',
                        detailColor: AppColors.success,
                        image: 'assets/images/pastora_ana.png',
                      ),
                    ),
                    Positioned(
                      left: rightGroup,
                      top: leafTop,
                      child: _TreePersonCard(
                        width: leafWidth,
                        height: leafHeight,
                        name: 'Pr. Marcos Lima',
                        detail: 'Último cuidado: 54 dias',
                        detailColor: AppColors.accent,
                        image: 'assets/images/pastor_marcos.png',
                        warning: true,
                      ),
                    ),
                    Positioned(
                      left: rightGroup + leafWidth + leafGap,
                      top: leafTop,
                      child: const _TreePersonCard(
                        width: leafWidth,
                        height: leafHeight,
                        name: 'Pr. Eduardo Costa',
                        detail: 'Próximo cuidado: 18/09',
                        detailColor: AppColors.primary,
                        initials: 'EC',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TreeConnectorPainter extends CustomPainter {
  const _TreeConnectorPainter({
    required this.rootBottomCenter,
    required this.branchY,
    required this.branchTopCenters,
    required this.branchBottomCenters,
    required this.leafTopCenters,
  });

  final Offset rootBottomCenter;
  final double branchY;
  final List<Offset> branchTopCenters;
  final List<Offset> branchBottomCenters;
  final List<List<Offset>> leafTopCenters;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      rootBottomCenter,
      Offset(rootBottomCenter.dx, branchY),
      paint,
    );
    canvas.drawLine(
      Offset(branchTopCenters.first.dx, branchY),
      Offset(branchTopCenters.last.dx, branchY),
      paint,
    );
    for (var i = 0; i < branchTopCenters.length; i++) {
      final branchTop = branchTopCenters[i];
      final branchBottom = branchBottomCenters[i];
      canvas.drawLine(Offset(branchTop.dx, branchY), branchTop, paint);

      final leaves = leafTopCenters[i];
      final leafBranchY = branchBottom.dy + 28;
      canvas.drawLine(
        branchBottom,
        Offset(branchBottom.dx, leafBranchY),
        paint,
      );
      canvas.drawLine(
        Offset(leaves.first.dx, leafBranchY),
        Offset(leaves.last.dx, leafBranchY),
        paint,
      );
      for (final leaf in leaves) {
        canvas.drawLine(Offset(leaf.dx, leafBranchY), leaf, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TreeConnectorPainter oldDelegate) => false;
}

String _initials(String name) {
  final words = name
      .replaceAll(RegExp(r'^(Pr\.|Pra\.|Pastor|Pastora)\s+'), '')
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.length < 2) {
    return name.substring(0, math.min(2, name.length)).toUpperCase();
  }
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

class _TreePersonCard extends StatelessWidget {
  const _TreePersonCard({
    required this.width,
    required this.height,
    required this.name,
    required this.detail,
    required this.detailColor,
    this.image,
    this.initials,
    this.emphasized = false,
    this.warning = false,
  });

  final double width;
  final double height;
  final String name;
  final String detail;
  final Color detailColor;
  final String? image;
  final String? initials;
  final bool emphasized;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppTokens.radius16),
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: emphasized ? 28 : 24,
                    backgroundColor: AppColors.softPrimary,
                    foregroundImage: image == null ? null : AssetImage(image!),
                    child: image == null
                        ? Text(
                            initials ?? _initials(name),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                  if (warning)
                    const Positioned(
                      right: -5,
                      bottom: -2,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.accent,
                        child: Icon(
                          Icons.priority_high_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.space8),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
                  fontSize: emphasized ? 14 : 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: detailColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TreeLegend extends StatelessWidget {
  const _TreeLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppTokens.space16,
      runSpacing: AppTokens.space8,
      children: const [
        _LegendItem(color: AppColors.success, label: 'Acompanhamento recente'),
        _LegendItem(color: AppColors.accent, label: 'Mais de 30 dias'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.mutedInk, fontSize: 11),
        ),
      ],
    );
  }
}
