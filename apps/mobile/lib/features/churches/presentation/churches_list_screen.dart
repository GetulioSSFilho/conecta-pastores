import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/paged_list_view.dart';
import '../../auth/application/auth_controller.dart';
import '../data/churches_providers.dart';
import '../domain/church_models.dart';

/// Diretório de igrejas, filtrado pelo escopo de quem consulta.
class ChurchesListScreen extends ConsumerStatefulWidget {
  const ChurchesListScreen({super.key});

  @override
  ConsumerState<ChurchesListScreen> createState() => _ChurchesListScreenState();
}

class _ChurchesListScreenState extends ConsumerState<ChurchesListScreen> {
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
      ref.read(churchQueryProvider.notifier).update((q) => q.copyWith(search: value.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final query = ref.watch(churchQueryProvider);
    final notifier = ref.read(churchQueryProvider.notifier);
    final total = ref.watch(churchesProvider).value?.total;
    final canCreate = ref.watch(currentUserProvider)?.can('church.write') ?? false;

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
                          'Igrejas',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          total == null
                              ? 'Sedes, campi e congregações'
                              : '$total ${total == 1 ? 'igreja' : 'igrejas'}',
                          style: const TextStyle(color: AppColors.mutedInk),
                        ),
                      ],
                    ),
                  ),
                  if (canCreate)
                    FilledButton.icon(
                      onPressed: () => context.go('/churches/new'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nova igreja'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(padding, AppTokens.space16, padding, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nome, código ou cidade',
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
                          selected: !query.hasFilters || (query.status == null && query.type == null),
                          onSelected: (_) => notifier.update(
                            (q) => q.copyWith(status: () => null, type: () => null),
                          ),
                        ),
                        for (final status in ChurchStatus.values) ...[
                          const SizedBox(width: AppTokens.space8),
                          ChoiceChip(
                            label: Text(status.label),
                            selected: query.status == status,
                            onSelected: (selected) => notifier.update(
                              (q) => q.copyWith(status: () => selected ? status : null),
                            ),
                          ),
                        ],
                        for (final type in ChurchType.values) ...[
                          const SizedBox(width: AppTokens.space8),
                          ChoiceChip(
                            avatar: Icon(type.icon, size: 18),
                            label: Text(type.label),
                            selected: query.type == type,
                            onSelected: (selected) => notifier.update(
                              (q) => q.copyWith(type: () => selected ? type : null),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _CountryFilter(query: query, notifier: notifier),
                ],
              ),
            ),
            Expanded(
              child: PagedListView(
                value: ref.watch(churchesProvider),
                padding: EdgeInsets.fromLTRB(
                  padding,
                  AppTokens.space16,
                  padding,
                  AppTokens.space32,
                ),
                onLoadMore: () => ref.read(churchesProvider.notifier).loadMore(),
                onRetry: () => ref.invalidate(churchesProvider),
                onRefresh: () async => ref.invalidate(churchesProvider),
                empty: InlineEmpty(
                  icon: query.hasFilters ? Icons.filter_alt_off_outlined : Icons.church_outlined,
                  message: query.hasFilters
                      ? 'Nenhuma igreja com esses filtros.'
                      : 'Nenhuma igreja no seu escopo.',
                  action: query.hasFilters
                      ? TextButton(
                          onPressed: () {
                            _search.clear();
                            notifier.set(const ChurchQuery());
                          },
                          child: const Text('Limpar filtros'),
                        )
                      : null,
                ),
                itemBuilder: (context, church) => _ChurchCard(church: church),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filtro por país: some quando o usuário não pode ler geografia (403).
class _CountryFilter extends ConsumerWidget {
  const _CountryFilter({required this.query, required this.notifier});

  final ChurchQuery query;
  final ChurchQueryNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(countriesProvider),
      hideWhenForbidden: true,
      loading: const SizedBox.shrink(),
      data: (countries) => countries.length < 2
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: AppTokens.space12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Todos os países'),
                      selected: query.countryId == null,
                      onSelected: (_) => notifier.update((q) => q.copyWith(countryId: () => null)),
                    ),
                    for (final country in countries) ...[
                      const SizedBox(width: AppTokens.space8),
                      ChoiceChip(
                        label: Text(country.name),
                        selected: query.countryId == country.id,
                        onSelected: (selected) => notifier.update(
                          (q) => q.copyWith(countryId: () => selected ? country.id : null),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _ChurchCard extends StatelessWidget {
  const _ChurchCard({required this.church});

  final Church church;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go('/churches/${church.id}'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.softPrimary,
              borderRadius: BorderRadius.circular(AppTokens.radius12),
            ),
            child: Icon(church.type.icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        church.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: AppTokens.space8),
                    Text(
                      church.code,
                      style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  church.placeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  [church.countsText, ?church.leadPastorName].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTokens.space8, vertical: 2),
                decoration: BoxDecoration(
                  color: church.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  church.status.label,
                  style: TextStyle(
                    color: church.status.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                church.type.label,
                style: const TextStyle(color: AppColors.mutedInk, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
