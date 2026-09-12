import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/paged_list_view.dart';
import '../../../core/widgets/searchable_select.dart';
import '../../auth/application/auth_controller.dart';
import '../../churches/data/church_options_provider.dart';
import '../data/pastor_directory_providers.dart';
import '../domain/pastor_status.dart';
import 'widgets/pastor_list_tile.dart';

/// Diretorio pastoral: busca por nome, igreja, pais, regiao, cidade e status.
/// Paginacao, filtros e ordenacao no servidor, sempre no escopo do usuario.
class PastorDirectoryScreen extends ConsumerStatefulWidget {
  const PastorDirectoryScreen({super.key});

  @override
  ConsumerState<PastorDirectoryScreen> createState() =>
      _PastorDirectoryScreenState();
}

class _PastorDirectoryScreenState extends ConsumerState<PastorDirectoryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final query = PastorQuery.fromUrl(
        GoRouterState.of(context).uri.queryParameters,
      );
      _search.text = query.search;
      ref.read(pastorQueryProvider.notifier).set(query);
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
          .read(pastorQueryProvider.notifier)
          .update((q) => q.copyWith(search: value.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final user = ref.watch(currentUserProvider);
    final total = ref.watch(pastorDirectoryProvider).value?.total;
    final hasFilters = ref.watch(
      pastorQueryProvider.select((q) => q.hasFilters),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
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
                          'Pastores',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          total == null
                              ? 'Diretório pastoral'
                              : '$total ${total == 1 ? 'pastor encontrado' : 'pastores encontrados'}',
                          style: const TextStyle(color: AppColors.mutedInk),
                        ),
                      ],
                    ),
                  ),
                  if (user?.can('pastor.write') ?? false)
                    FilledButton.icon(
                      onPressed: () => context.go('/pastors/new'),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Novo pastor'),
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
              child: _DirectoryFilters(search: _search, onSearch: _onSearch),
            ),
            Expanded(
              child: !_ready
                  ? const SizedBox.shrink()
                  : PagedListView(
                      value: ref.watch(pastorDirectoryProvider),
                      padding: EdgeInsets.fromLTRB(
                        padding,
                        AppTokens.space16,
                        padding,
                        AppTokens.space32,
                      ),
                      onLoadMore: () =>
                          ref.read(pastorDirectoryProvider.notifier).loadMore(),
                      onRetry: () => ref.invalidate(pastorDirectoryProvider),
                      onRefresh: () async =>
                          ref.invalidate(pastorDirectoryProvider),
                      empty: InlineEmpty(
                        icon: hasFilters
                            ? Icons.filter_alt_off_outlined
                            : Icons.people_outline_rounded,
                        message: hasFilters
                            ? 'Nenhum pastor encontrado com esses filtros.'
                            : 'Nenhum pastor cadastrado na sua área.',
                        action: hasFilters
                            ? TextButton(
                                onPressed: () {
                                  _search.clear();
                                  ref
                                      .read(pastorQueryProvider.notifier)
                                      .set(const PastorQuery());
                                },
                                child: const Text('Limpar filtros'),
                              )
                            : null,
                      ),
                      itemBuilder: (context, pastor) => PastorListTile(
                        pastor: pastor,
                        onTap: () => context.go('/pastors/${pastor.id}'),
                        onRegisterCare: (user?.can('care.write') ?? false)
                            ? () =>
                                  context.go('/care/new?pastorId=${pastor.id}')
                            : null,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectoryFilters extends ConsumerWidget {
  const _DirectoryFilters({required this.search, required this.onSearch});

  final TextEditingController search;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(pastorQueryProvider);
    final notifier = ref.read(pastorQueryProvider.notifier);
    final churches =
        ref.watch(scopedChurchOptionsProvider).value ?? const <ChurchOption>[];
    final countries = countriesOf(churches);
    final regions = regionsOf(churches, countryId: query.countryId);
    final visibleChurches = churches
        .where(
          (c) =>
              (query.countryId == null || c.countryId == query.countryId) &&
              (query.regionId == null || c.regionId == query.regionId),
        )
        .toList();

    String labelOf(List<FilterOption> options, String? id, String fallback) {
      for (final o in options) {
        if (o.id == id) return o.label;
      }
      return fallback;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: search,
          onChanged: onSearch,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Buscar por nome, e-mail, cidade ou igreja',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: AppTokens.space12),
        Wrap(
          spacing: AppTokens.space8,
          runSpacing: AppTokens.space8,
          children: [
            _FilterMenu(
              icon: Icons.verified_user_outlined,
              label: query.status == null
                  ? 'Status'
                  : PastorStatus.fromApi(query.status).label,
              active: query.status != null,
              options: [
                (id: '', label: 'Todos os status'),
                for (final s in PastorStatus.values)
                  (id: s.apiValue, label: s.label),
              ],
              onSelected: (id) => notifier.update(
                (q) => q.copyWith(status: () => id.isEmpty ? null : id),
              ),
            ),
            if (countries.length > 1)
              _FilterMenu(
                icon: Icons.public_rounded,
                label: labelOf(countries, query.countryId, 'País'),
                active: query.countryId != null,
                options: [(id: '', label: 'Todos os países'), ...countries],
                onSelected: (id) => notifier.update(
                  (q) => q.copyWith(
                    countryId: () => id.isEmpty ? null : id,
                    regionId: () => null,
                    churchId: () => null,
                  ),
                ),
              ),
            if (regions.isNotEmpty)
              _FilterMenu(
                icon: Icons.map_outlined,
                label: labelOf(regions, query.regionId, 'Região'),
                active: query.regionId != null,
                options: [(id: '', label: 'Todas as regiões'), ...regions],
                onSelected: (id) => notifier.update(
                  (q) => q.copyWith(
                    regionId: () => id.isEmpty ? null : id,
                    churchId: () => null,
                  ),
                ),
              ),
            if (visibleChurches.isNotEmpty)
              _FilterMenu(
                icon: Icons.church_outlined,
                label: labelOf(
                  [for (final c in visibleChurches) (id: c.id, label: c.name)],
                  query.churchId,
                  'Igreja',
                ),
                active: query.churchId != null,
                options: [
                  (id: '', label: 'Todas as igrejas'),
                  for (final c in visibleChurches) (id: c.id, label: c.name),
                ],
                onSelected: (id) => notifier.update(
                  (q) => q.copyWith(churchId: () => id.isEmpty ? null : id),
                ),
              ),
            _FilterMenu(
              icon: Icons.sort_rounded,
              label: query.sort.label,
              active: query.sort != PastorSort.name,
              options: [
                for (final s in PastorSort.values) (id: s.name, label: s.label),
              ],
              onSelected: (id) => notifier.update(
                (q) => q.copyWith(sort: PastorSort.values.byName(id)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.icon,
    required this.label,
    required this.active,
    required this.options,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool active;
  final List<FilterOption> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SearchableFilterButton<String>(
      icon: icon,
      label: label,
      active: active,
      options: [
        for (final option in options)
          SearchableMenuOption(value: option.id, label: option.label),
      ],
      onSelected: onSelected,
    );
  }
}
