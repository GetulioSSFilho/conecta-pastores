import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/demo_pastor_photos.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/paged_list_view.dart';
import '../../../core/widgets/searchable_select.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
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

class _NetworkTree extends StatefulWidget {
  const _NetworkTree({
    required this.padding,
    required this.filter,
    required this.search,
  });

  final double padding;
  final _TreeFilter filter;
  final String search;

  @override
  State<_NetworkTree> createState() => _NetworkTreeState();
}

class _NetworkTreeState extends State<_NetworkTree> {
  final _scrollLock = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _scrollLock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _scrollLock,
      builder: (context, locked, _) => TreeScrollLockScope(
        lock: _scrollLock,
        child: _NetworkTreeContent(
          padding: widget.padding,
          filter: widget.filter,
          search: widget.search,
          scrollLocked: locked,
        ),
      ),
    );
  }
}

class _NetworkTreeContent extends StatelessWidget {
  const _NetworkTreeContent({
    required this.padding,
    required this.filter,
    required this.search,
    required this.scrollLocked,
  });

  final double padding;
  final _TreeFilter filter;
  final String search;
  final bool scrollLocked;

  @override
  Widget build(BuildContext context) {
    final filterLabel = switch (filter) {
      _TreeFilter.all => null,
      _TreeFilter.overdue => 'Mais de 30 dias',
      _TreeFilter.thisWeek => 'Esta semana',
    };

    return ListView(
      physics: scrollLocked ? const NeverScrollableScrollPhysics() : null,
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
        _ExpandableTreeGraph(filter: filter),
        const SizedBox(height: AppTokens.space16),
        const _TreeLegend(),
      ],
    );
  }
}

/// Organograma visual da referência. É deliberadamente um exemplo local:
/// permite validar a composição antes de decidir o contrato persistido da
/// árvore real.
// ignore: unused_element
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
        return _ZoomableTree(
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
                        name: 'Pr. André Valadão',
                        detail: 'Presidente · Lagoinha Global',
                        detailColor: AppColors.primary,
                        image: 'assets/images/mock_pastores/andre_valadao.jpg',
                        emphasized: true,
                      ),
                    ),
                    Positioned(
                      left: leftBranch,
                      top: branchTop,
                      child: const _TreePersonCard(
                        width: branchWidth,
                        height: branchHeight,
                        name: 'Pr. Rodinei Medeiros',
                        detail: 'Sobre-regional · Betim e RMBH',
                        detailColor: AppColors.primary,
                        image:
                            'assets/images/mock_pastores/rodinei_medeiros.jpg',
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

/// Versão reutilizável do organograma para o dashboard e para a tela Minha
/// Rede. Mantém a mesma árvore, expansão e experiência de zoom.
class NetworkTreeOrganogram extends StatelessWidget {
  const NetworkTreeOrganogram({super.key});

  @override
  Widget build(BuildContext context) =>
      const _ExpandableTreeGraph(filter: _TreeFilter.all);
}

/// Coordena o gesto do organograma com a rolagem vertical que o envolve.
/// Enquanto um ponteiro estiver dentro do viewport, a lista pai fica travada;
/// ao soltar, a rolagem da tela volta ao comportamento normal.
class TreeScrollLockScope extends InheritedWidget {
  const TreeScrollLockScope({
    super.key,
    required this.lock,
    required super.child,
  });

  final ValueNotifier<bool> lock;

  static ValueNotifier<bool>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TreeScrollLockScope>()?.lock;

  @override
  bool updateShouldNotify(TreeScrollLockScope oldWidget) =>
      lock != oldWidget.lock;
}

/// Viewport do organograma com zoom por pinça no celular e controles para
/// mouse, teclado e apresentação em telas maiores.
class _ZoomableTree extends StatefulWidget {
  const _ZoomableTree({required this.child});

  final Widget child;

  @override
  State<_ZoomableTree> createState() => _ZoomableTreeState();
}

class _ZoomableTreeState extends State<_ZoomableTree> {
  static const _minScale = 0.35;
  static const _maxScale = 2.5;

  final _controller = TransformationController();
  var _activePointers = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scale(double factor) {
    final current = _controller.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(_minScale, _maxScale).toDouble();
    final matrix = Matrix4.copy(_controller.value)
      ..setEntry(0, 0, next)
      ..setEntry(1, 1, next)
      ..setEntry(2, 2, next);
    _controller.value = matrix;
  }

  /// O InteractiveViewer limita a escala durante o gesto, mas o valor vindo
  /// da pinça pode passar alguns décimos do limite entre dois frames. Fazemos
  /// a mesma normalização dos botões e preservamos a posição do organograma.
  void _clampScale() {
    final current = _controller.value.getMaxScaleOnAxis();
    final next = current.clamp(_minScale, _maxScale).toDouble();
    if ((current - next).abs() < 0.0001 || current == 0) return;
    final matrix = Matrix4.copy(_controller.value)
      ..scaleByDouble(next / current, next / current, next / current, 1.0);
    _controller.value = matrix;
  }

  void _pointerDown(PointerDownEvent _) {
    _activePointers++;
    TreeScrollLockScope.maybeOf(context)?.value = true;
  }

  void _pointerUp(PointerEvent _) {
    _activePointers = math.max(0, _activePointers - 1);
    if (_activePointers == 0) {
      TreeScrollLockScope.maybeOf(context)?.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewportHeight = context.windowSize.isCompact ? 420.0 : 460.0;
    return SizedBox(
      height: viewportHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        child: Stack(
          children: [
            Listener(
              onPointerDown: _pointerDown,
              onPointerUp: _pointerUp,
              onPointerCancel: _pointerUp,
              child: InteractiveViewer(
                transformationController: _controller,
                constrained: false,
                minScale: _minScale,
                maxScale: _maxScale,
                boundaryMargin: const EdgeInsets.all(180),
                panEnabled: true,
                scaleEnabled: true,
                onInteractionUpdate: (_) => _clampScale(),
                onInteractionEnd: (_) => _clampScale(),
                clipBehavior: Clip.hardEdge,
                child: widget.child,
              ),
            ),
            Positioned(
              top: AppTokens.space12,
              right: AppTokens.space12,
              child: Material(
                color: AppColors.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(AppTokens.radius12),
                elevation: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Diminuir zoom',
                      onPressed: () => _scale(0.8),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    IconButton(
                      tooltip: 'Aumentar zoom',
                      onPressed: () => _scale(1.25),
                      icon: const Icon(Icons.add_rounded),
                    ),
                    IconButton(
                      tooltip: 'Redefinir zoom',
                      onPressed: () => _controller.value = Matrix4.identity(),
                      icon: const Icon(Icons.center_focus_strong_rounded),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: AppTokens.space12,
              bottom: AppTokens.space12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(AppTokens.pill),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    'Pin\u00e7a para ampliar · arraste para navegar',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Organograma hierárquico expansível da demonstração.
///
/// Presidente e sobre-regionais aparecem no primeiro nível. Cada botão "+"
/// abre somente o próximo nível, mantendo a leitura limpa mesmo com muitos
/// pastores. A árvore é reduzida ao escopo do perfil antes de ser desenhada.
class _ExpandableTreeGraph extends ConsumerStatefulWidget {
  const _ExpandableTreeGraph({required this.filter});

  final _TreeFilter filter;

  @override
  ConsumerState<_ExpandableTreeGraph> createState() =>
      _ExpandableTreeGraphState();
}

class _ExpandableTreeGraphState extends ConsumerState<_ExpandableTreeGraph> {
  final _expanded = <String>{'presidente'};

  @override
  Widget build(BuildContext context) {
    final root = _treeForScope(ref.watch(currentUserProvider));
    final layout = _ExpandableTreeLayout.build(root, _expanded);
    const graphPadding = 28.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          constraints.maxWidth,
          layout.width + graphPadding * 2,
        );
        return _ZoomableTree(
          child: SizedBox(
            width: width,
            height: layout.height + graphPadding * 2,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ExpandableTreeConnectorPainter(
                      edges: layout.edges,
                      offset: const Offset(graphPadding, graphPadding),
                    ),
                  ),
                ),
                for (final item in layout.nodes)
                  Positioned(
                    left: item.position.dx + graphPadding,
                    top: item.position.dy + graphPadding,
                    child: _ExpandableTreePersonCard(
                      node: item.node,
                      expanded: _expanded.contains(item.node.id),
                      onTap: () => _openNodeProfile(item.node),
                      onToggle: () => setState(() {
                        if (!_expanded.add(item.node.id)) {
                          _expanded.remove(item.node.id);
                        }
                      }),
                      detail: _treeDetail(item.node),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _treeDetail(_DemoTreeNode node) {
    if (widget.filter == _TreeFilter.thisWeek && node.nextDetail != null) {
      return node.nextDetail!;
    }
    return node.detail;
  }

  void _openNodeProfile(_DemoTreeNode node) {
    final uri = Uri(
      path: '/pastors/${node.id}',
      queryParameters: {
        'demo': '1',
        'name': node.name,
        'detail': _treeDetail(node),
        'image': node.image,
      },
    );
    context.push(uri.toString());
  }
}

enum _DemoTreeLevel { president, overRegional, regional, subRegional, local }

class _DemoTreeNode {
  const _DemoTreeNode({
    required this.id,
    required this.name,
    required this.detail,
    required this.image,
    required this.level,
    this.children = const [],
    this.detailColor = AppColors.primary,
    this.nextDetail,
    this.warning = false,
  });

  final String id;
  final String name;
  final String detail;
  final String image;
  final _DemoTreeLevel level;
  final List<_DemoTreeNode> children;
  final Color detailColor;
  final String? nextDetail;
  final bool warning;
}

_DemoTreeNode _treeForScope(AuthUser? user) {
  final root = _completeDemoTree();
  if (user == null) return root;
  final roles = user.roles;
  if (roles.contains('GLOBAL_ADMIN') || roles.contains('NATIONAL_LEADER')) {
    return root;
  }
  if (roles.contains('REGIONAL_LEADER')) {
    return _treeBranch(root, const [
      'presidente',
      'sobre-sudeste',
    ], includeDescendants: true);
  }
  if (roles.contains('SUPERVISOR') || user.isLeader) {
    return _treeBranch(root, const [
      'presidente',
      'sobre-sudeste',
      'regional-rmbh',
      'sub-centro',
    ], includeDescendants: true);
  }
  return _treeBranch(root, const [
    'presidente',
    'sobre-sudeste',
    'regional-rmbh',
    'sub-centro',
    'pastor-joao',
  ]);
}

_DemoTreeNode _treeBranch(
  _DemoTreeNode node,
  List<String> path, {
  bool includeDescendants = false,
}) {
  if (path.length <= 1) {
    return includeDescendants ? node : _demoCopy(node, const []);
  }
  final child = node.children.firstWhere((item) => item.id == path[1]);
  return _demoCopy(node, [
    _treeBranch(child, path.sublist(1), includeDescendants: includeDescendants),
  ]);
}

_DemoTreeNode _demoCopy(_DemoTreeNode node, List<_DemoTreeNode> children) =>
    _DemoTreeNode(
      id: node.id,
      name: node.name,
      detail: node.detail,
      image: node.image,
      level: node.level,
      children: children,
      detailColor: node.detailColor,
      nextDetail: node.nextDetail,
      warning: node.warning,
    );

// ignore: unused_element
_DemoTreeNode _demoTree() => const _DemoTreeNode(
  id: 'presidente',
  name: 'Pr. Carlos Mendes',
  detail: 'Presidente · Igreja Monte Carmo',
  image: 'assets/images/pastor_carlos.png',
  level: _DemoTreeLevel.president,
  children: [
    _DemoTreeNode(
      id: 'sobre-sudeste',
      name: 'Pr. Paulo Ribeiro',
      detail: 'Sobre-regional · Sudeste',
      image: 'assets/images/pastor_joao.png',
      level: _DemoTreeLevel.overRegional,
      children: [
        _DemoTreeNode(
          id: 'regional-rmbh',
          name: 'Pr. Jo\u00e3o Silva',
          detail: 'Regional · RMBH',
          image: 'assets/images/pastor_joao.png',
          level: _DemoTreeLevel.regional,
          children: [
            _DemoTreeNode(
              id: 'sub-centro',
              name: 'Pr. Lucas Ferreira',
              detail: 'Sub-regional · Centro',
              image: 'assets/images/pastor_marcos.png',
              level: _DemoTreeLevel.subRegional,
              children: [
                _DemoTreeNode(
                  id: 'pastor-joao',
                  name: 'Pr. Jo\u00e3o Silva',
                  detail: 'Pastor local · 8 dias',
                  image: 'assets/images/pastor_joao.png',
                  level: _DemoTreeLevel.local,
                  detailColor: AppColors.success,
                  nextDetail: 'Pr\u00f3ximo cuidado: 18/09',
                ),
                _DemoTreeNode(
                  id: 'pastora-ana',
                  name: 'Pra. Ana Souza',
                  detail: 'Pastora local · 12 dias',
                  image: 'assets/images/pastora_ana.png',
                  level: _DemoTreeLevel.local,
                  detailColor: AppColors.success,
                  nextDetail: 'Pr\u00f3ximo cuidado: 20/09',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    _DemoTreeNode(
      id: 'sobre-centro-oeste',
      name: 'Pra. Renata Almeida',
      detail: 'Sobre-regional · Centro-Oeste',
      image: 'assets/images/pastora_ana.png',
      level: _DemoTreeLevel.overRegional,
      children: [
        _DemoTreeNode(
          id: 'regional-brasilia',
          name: 'Pra. Ana Oliveira',
          detail: 'Regional · Bras\u00edlia',
          image: 'assets/images/pastora_lucia.png',
          level: _DemoTreeLevel.regional,
          children: [
            _DemoTreeNode(
              id: 'sub-planalto',
              name: 'Pr. Andr\u00e9 Rocha',
              detail: 'Sub-regional · Planalto',
              image: 'assets/images/pastor_carlos.png',
              level: _DemoTreeLevel.subRegional,
              children: [
                _DemoTreeNode(
                  id: 'pastor-marcos',
                  name: 'Pr. Marcos Lima',
                  detail: 'Pastor local · 54 dias',
                  image: 'assets/images/pastor_marcos.png',
                  level: _DemoTreeLevel.local,
                  detailColor: AppColors.accent,
                  nextDetail: 'Pr\u00f3ximo cuidado: 18/09',
                  warning: true,
                ),
                _DemoTreeNode(
                  id: 'pastor-eduardo',
                  name: 'Pr. Eduardo Costa',
                  detail: 'Pastor local · Agenda em dia',
                  image: 'assets/images/pastor_carlos.png',
                  level: _DemoTreeLevel.local,
                  nextDetail: 'Pr\u00f3ximo cuidado: 18/09',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Gera os dados de demonstração completos: 4 sobre-regionais, 12 regionais,
/// 24 sub-regionais e 109 pastores locais. Os dados continuam locais enquanto
/// o contrato definitivo de organograma não for persistido.
_DemoTreeNode _completeDemoTree() {
  const overRegions = [
    (
      'sobre-sudeste',
      'Pr. Rodinei Medeiros',
      'Betim e RMBH',
      'assets/images/mock_pastores/rodinei_medeiros.jpg',
      ['RMBH', 'Vale do Aço', 'Triângulo'],
    ),
    (
      'sobre-centro-oeste',
      'Pra. Renata Almeida',
      'Centro-Oeste',
      'assets/images/pastora_ana.png',
      ['Brasília', 'Goiânia', 'Campo Grande'],
    ),
    (
      'sobre-nordeste',
      'Pr. Elias Carvalho',
      'Nordeste',
      'assets/images/pastor_carlos.png',
      ['Salvador', 'Recife', 'Fortaleza'],
    ),
    (
      'sobre-norte-sul',
      'Pra. Miriam Azevedo',
      'Norte e Sul',
      'assets/images/pastora_lucia.png',
      ['Belém', 'Curitiba', 'Porto Alegre'],
    ),
  ];
  const regionalLeaders = [
    'Pr. Jo\u00e3o Silva',
    'Pra. Marta Oliveira',
    'Pr. Marcos Lima',
    'Pra. Ana Oliveira',
    'Pr. Daniel Martins',
    'Pra. Beatriz Lima',
    'Pr. Samuel Costa',
    'Pra. Juliana Reis',
    'Pr. Andr\u00e9 Rocha',
    'Pra. Helena Dias',
    'Pr. Pedro Alves',
    'Pra. Camila Souza',
  ];
  const subRegionalLeaders = [
    'Pr. Lucas Ferreira',
    'Pra. Marta Oliveira',
    'Pr. Samuel Costa',
    'Pra. Juliana Reis',
    'Pr. Andr\u00e9 Rocha',
    'Pra. Helena Dias',
    'Pr. Pedro Alves',
    'Pra. Camila Souza',
    'Pr. Rafael Nunes',
    'Pra. Patr\u00edcia Alves',
    'Pr. Tiago Martins',
    'Pra. Cl\u00e1udia Reis',
  ];
  const localFirstNames = [
    'Jo\u00e3o',
    'Ana',
    'Marcos',
    'Eduardo',
    'Lucas',
    'Marta',
    'Andr\u00e9',
    'Juliana',
    'Rafael',
    'Camila',
    'Daniel',
    'Beatriz',
    'Samuel',
    'Helena',
    'Pedro',
    'Patr\u00edcia',
    'Tiago',
    'Cl\u00e1udia',
    'Felipe',
    'Renata',
  ];
  const localSurnames = [
    'Silva',
    'Souza',
    'Lima',
    'Costa',
    'Oliveira',
    'Ferreira',
    'Almeida',
    'Carvalho',
    'Ribeiro',
    'Martins',
    'Nogueira',
    'Azevedo',
    'Barros',
    'Teixeira',
    'Pereira',
  ];
  const knownNames = [
    'Pr. João Silva',
    'Pra. Ana Souza',
    'Pr. Eduardo Camilo',
    'Pra. Ana Carolina',
    'Pr. Cledson Silveira',
    'Pr. Natan',
    'Pr. Euler',
    'Pr. Wellington',
  ];
  const localChurches = [
    'Lagoinha Betim · Betim-MG',
    'Lagoinha PTB · Betim-MG',
    'Lagoinha Marimbá · Betim-MG',
    'Lagoinha Citrolândia · Betim-MG',
    'Lagoinha Monte Carmo · Betim-MG',
    'Lagoinha Matriz · Belo Horizonte-MG',
    'Lagoinha Duque de Caxias · Rio de Janeiro-RJ',
    'Lagoinha Orlando · Orlando-EUA',
    'Lagoinha Lisboa · Odivelas-Portugal',
    'Lagoinha Barra Funda · São Paulo-SP',
    'Lagoinha Americana · Americana-SP',
    'Lagoinha Costa Rica · Costa Rica-MS',
    'Lagoinha Fernão Dias · Belo Horizonte-MG',
  ];
  var pastorIndex = 0;
  var malePhotoIndex = 0;
  var femalePhotoIndex = 0;
  String nextPhoto(String name) {
    final female = DemoPastorPhotos.isFemaleName(name);
    return female
        ? DemoPastorPhotos.nextFemalePhoto(femalePhotoIndex++)
        : DemoPastorPhotos.nextMalePhoto(malePhotoIndex++);
  }

  var regionalIndex = 0;
  var subRegionalIndex = 0;
  final overRegionalNodes = <_DemoTreeNode>[];

  for (var overIndex = 0; overIndex < overRegions.length; overIndex++) {
    final over = overRegions[overIndex];
    final regionalNodes = <_DemoTreeNode>[];
    for (var regionIndex = 0; regionIndex < over.$5.length; regionIndex++) {
      final regionId = overIndex == 0 && regionIndex == 0
          ? 'regional-rmbh'
          : 'regional-$overIndex-$regionIndex';
      final subRegionalNodes = <_DemoTreeNode>[];
      for (var subIndex = 0; subIndex < 2; subIndex++) {
        final subId = overIndex == 0 && regionIndex == 0 && subIndex == 0
            ? 'sub-centro'
            : 'sub-$overIndex-$regionIndex-$subIndex';
        final localNodes = <_DemoTreeNode>[];
        // 13 dos 24 sub-regionais recebem cinco pastores e os demais quatro:
        // total de 109, distribuídos sem concentrar toda a rede em um ramo.
        final localCount = subRegionalIndex < 13 ? 5 : 4;
        for (var localIndex = 0; localIndex < localCount; localIndex++) {
          final index = pastorIndex++;
          final name = index < knownNames.length
              ? knownNames[index]
              : '${index.isEven ? 'Pr.' : 'Pra.'} '
                    '${localFirstNames[(index - 4) % localFirstNames.length]} '
                    '${localSurnames[(index - 4) ~/ localFirstNames.length % localSurnames.length]}';
          final church = localChurches[index % localChurches.length];
          final detail = index == 2
              ? 'Pastor local \u00b7 $church \u00b7 54 dias'
              : index == 3
              ? 'Pastor local \u00b7 $church \u00b7 agenda em dia'
              : 'Pastor local \u00b7 $church \u00b7 ${8 + (index * 3) % 31} dias';
          localNodes.add(
            _DemoTreeNode(
              id: index == 0 ? 'pastor-joao' : 'pastor-$index',
              name: name,
              detail: detail,
              image: nextPhoto(name),
              level: _DemoTreeLevel.local,
              detailColor: index == 2 ? AppColors.accent : AppColors.success,
              nextDetail: index.isEven ? 'Pr\u00f3ximo cuidado: 18/09' : null,
              warning: index == 2,
            ),
          );
        }
        final subName =
            subRegionalLeaders[subRegionalIndex % subRegionalLeaders.length];
        subRegionalNodes.add(
          _DemoTreeNode(
            id: subId,
            name: subName,
            detail: 'Sub-regional \u00b7 ${over.$5[regionIndex]}',
            image: nextPhoto(subName),
            level: _DemoTreeLevel.subRegional,
            children: localNodes,
          ),
        );
        subRegionalIndex++;
      }
      final regionalName = regionalLeaders[regionalIndex++];
      regionalNodes.add(
        _DemoTreeNode(
          id: regionId,
          name: regionalName,
          detail: 'Regional \u00b7 ${over.$5[regionIndex]}',
          image: nextPhoto(regionalName),
          level: _DemoTreeLevel.regional,
          children: subRegionalNodes,
        ),
      );
    }
    overRegionalNodes.add(
      _DemoTreeNode(
        id: over.$1,
        name: over.$2,
        detail: 'Sobre-regional \u00b7 ${over.$3}',
        image: over.$4,
        level: _DemoTreeLevel.overRegional,
        children: regionalNodes,
      ),
    );
  }

  return _DemoTreeNode(
    id: 'presidente',
    name: 'Pr. Andr\u00e9 Valad\u00e3o',
    detail: 'Presidente \u00b7 Lagoinha Global',
    image: 'assets/images/mock_pastores/andre_valadao.jpg',
    level: _DemoTreeLevel.president,
    children: overRegionalNodes,
  );
}

class _ExpandableTreeLayoutNode {
  const _ExpandableTreeLayoutNode(this.position, this.node);

  final Offset position;
  final _DemoTreeNode node;
}

class _ExpandableTreeEdge {
  const _ExpandableTreeEdge(this.from, this.to);

  final Offset from;
  final Offset to;
}

class _ExpandableTreeLayoutData {
  const _ExpandableTreeLayoutData({
    required this.width,
    required this.height,
    required this.nodes,
    required this.edges,
  });

  final double width;
  final double height;
  final List<_ExpandableTreeLayoutNode> nodes;
  final List<_ExpandableTreeEdge> edges;
}

class _ExpandableTreeLayout {
  static const nodeWidth = 156.0;
  static const nodeHeight = 142.0;
  static const horizontalGap = 24.0;
  static const verticalGap = 42.0;

  static _ExpandableTreeLayoutData build(
    _DemoTreeNode root,
    Set<String> expanded,
  ) {
    final nodes = <_ExpandableTreeLayoutNode>[];
    final edges = <_ExpandableTreeEdge>[];
    final result = _measure(root, expanded, nodes, edges);
    return _ExpandableTreeLayoutData(
      width: result.width,
      height: result.height,
      nodes: nodes,
      edges: edges,
    );
  }

  static ({double width, double height}) _measure(
    _DemoTreeNode node,
    Set<String> expanded,
    List<_ExpandableTreeLayoutNode> nodes,
    List<_ExpandableTreeEdge> edges, {
    double left = 0,
    double top = 0,
  }) {
    final children = expanded.contains(node.id)
        ? node.children
        : const <_DemoTreeNode>[];
    if (children.isEmpty) {
      nodes.add(_ExpandableTreeLayoutNode(Offset(left, top), node));
      return (width: nodeWidth, height: nodeHeight);
    }

    final childSizes = [
      for (final child in children) _subtreeSize(child, expanded),
    ];
    final childrenWidth =
        childSizes.fold<double>(0, (total, size) => total + size.width) +
        horizontalGap * (children.length - 1);
    final width = math.max(nodeWidth, childrenWidth);
    final nodeLeft = left + (width - nodeWidth) / 2;
    nodes.add(_ExpandableTreeLayoutNode(Offset(nodeLeft, top), node));

    var childLeft = left + (width - childrenWidth) / 2;
    final childTop = top + nodeHeight + verticalGap;
    var maxChildHeight = 0.0;
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final childSize = _measure(
        child,
        expanded,
        nodes,
        edges,
        left: childLeft,
        top: childTop,
      );
      edges.add(
        _ExpandableTreeEdge(
          Offset(nodeLeft + nodeWidth / 2, top + nodeHeight),
          Offset(childLeft + childSizes[i].width / 2, childTop),
        ),
      );
      childLeft += childSizes[i].width + horizontalGap;
      maxChildHeight = math.max(maxChildHeight, childSize.height);
    }
    return (width: width, height: nodeHeight + verticalGap + maxChildHeight);
  }

  static ({double width, double height}) _subtreeSize(
    _DemoTreeNode node,
    Set<String> expanded,
  ) {
    final nodes = <_ExpandableTreeLayoutNode>[];
    final edges = <_ExpandableTreeEdge>[];
    return _measure(node, expanded, nodes, edges);
  }
}

class _ExpandableTreePersonCard extends StatelessWidget {
  const _ExpandableTreePersonCard({
    required this.node,
    required this.expanded,
    required this.onTap,
    required this.onToggle,
    required this.detail,
  });

  final _DemoTreeNode node;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _ExpandableTreeLayout.nodeWidth,
      height: _ExpandableTreeLayout.nodeHeight,
      child: Stack(
        children: [
          _TreePersonCard(
            width: _ExpandableTreeLayout.nodeWidth,
            height: _ExpandableTreeLayout.nodeHeight,
            name: node.name,
            detail: detail,
            detailColor: node.detailColor,
            image: node.image,
            emphasized: node.level == _DemoTreeLevel.president,
            warning: node.warning,
            onTap: onTap,
          ),
          if (node.children.isNotEmpty)
            Positioned(
              top: 6,
              right: 6,
              child: Semantics(
                button: true,
                label: expanded
                    ? 'Recolher ${node.name}'
                    : 'Expandir ${node.name}',
                child: Material(
                  color: AppColors.softPrimary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onToggle,
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: Icon(
                        expanded ? Icons.remove_rounded : Icons.add_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpandableTreeConnectorPainter extends CustomPainter {
  const _ExpandableTreeConnectorPainter({
    required this.edges,
    required this.offset,
  });

  final List<_ExpandableTreeEdge> edges;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final edge in edges) {
      final from = edge.from + offset;
      final to = edge.to + offset;
      final middleY = from.dy + (to.dy - from.dy) / 2;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(from.dx, middleY)
        ..lineTo(to.dx, middleY)
        ..lineTo(to.dx, to.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExpandableTreeConnectorPainter oldDelegate) =>
      oldDelegate.edges != edges || oldDelegate.offset != offset;
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
    this.onTap,
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppTokens.radius16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        child: Semantics(
          button: onTap != null,
          label: onTap == null ? null : 'Abrir perfil de $name',
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
                        foregroundImage: image == null
                            ? null
                            : _treeImageProvider(image!),
                        onForegroundImageError: image == null
                            ? null
                            : (_, _) {},
                        child: Text(
                          initials ?? _initials(name),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
                      fontWeight: emphasized
                          ? FontWeight.w800
                          : FontWeight.w700,
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
        ),
      ),
    );
  }
}

ImageProvider<Object> _treeImageProvider(String source) =>
    source.startsWith('http') ? NetworkImage(source) : AssetImage(source);

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
