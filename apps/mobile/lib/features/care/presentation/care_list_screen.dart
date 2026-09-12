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
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../data/care_providers.dart';
import '../domain/care_models.dart';

/// Historico de cuidado pastoral da rede do usuario.
///
/// Indicadores e textos falam de FATOS (datas, dias, próxima ação),
/// nunca de julgamento sobre a pessoa.
class CareListScreen extends ConsumerStatefulWidget {
  const CareListScreen({super.key});

  @override
  ConsumerState<CareListScreen> createState() => _CareListScreenState();
}

class _CareListScreenState extends ConsumerState<CareListScreen> {
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
          .read(careQueryProvider.notifier)
          .update((q) => q.copyWith(search: value.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final query = ref.watch(careQueryProvider);
    final notifier = ref.read(careQueryProvider.notifier);
    final canWrite = ref.watch(currentUserProvider)?.can('care.write') ?? false;
    final types = ref.watch(careTypesProvider);
    final total = ref.watch(careListProvider).value?.total;

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
                          'Acompanhamentos',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          total == null
                              ? 'Registros de cuidado da sua rede'
                              : '$total ${total == 1 ? 'registro' : 'registros'} no período',
                          style: const TextStyle(color: AppColors.mutedInk),
                        ),
                      ],
                    ),
                  ),
                  if (canWrite)
                    FilledButton.icon(
                      onPressed: () => context.go('/care/new'),
                      icon: const Icon(Icons.add_task_rounded),
                      label: const Text('Registrar'),
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
                      hintText: 'Buscar por resumo ou próxima ação',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (days, label) in const [
                          (30, '30 dias'),
                          (90, '90 dias'),
                          (365, '1 ano'),
                          (0, 'Tudo'),
                        ]) ...[
                          ChoiceChip(
                            label: Text(label),
                            selected: query.days == days,
                            onSelected: (_) =>
                                notifier.update((q) => q.copyWith(days: days)),
                          ),
                          const SizedBox(width: AppTokens.space8),
                        ],
                        const SizedBox(width: AppTokens.space8),
                        types.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (list) => Row(
                            children: [
                              for (final type in list) ...[
                                FilterChip(
                                  avatar: Icon(
                                    type.icon,
                                    size: 18,
                                    color: type.color,
                                  ),
                                  label: Text(type.name),
                                  selected: query.typeId == type.id,
                                  onSelected: (v) => notifier.update(
                                    (q) => q.copyWith(
                                      typeId: () => v ? type.id : null,
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
                ],
              ),
            ),
            Expanded(
              child: PagedListView(
                value: ref.watch(careListProvider),
                padding: EdgeInsets.fromLTRB(
                  padding,
                  AppTokens.space16,
                  padding,
                  AppTokens.space32,
                ),
                onLoadMore: () =>
                    ref.read(careListProvider.notifier).loadMore(),
                onRetry: () => ref.invalidate(careListProvider),
                onRefresh: () async => ref.invalidate(careListProvider),
                empty: InlineEmpty(
                  icon: query.hasFilters
                      ? Icons.filter_alt_off_outlined
                      : Icons.volunteer_activism_outlined,
                  message: query.hasFilters
                      ? 'Nenhum acompanhamento com esses filtros.'
                      : 'Nenhum acompanhamento registrado ainda.',
                  action: canWrite
                      ? FilledButton(
                          onPressed: () => context.go('/care/new'),
                          child: const Text('Registrar acompanhamento'),
                        )
                      : null,
                ),
                itemBuilder: (context, record) => _CareCard(record: record),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareCard extends ConsumerWidget {
  const _CareCard({required this.record});

  final CareRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _CareDetailSheet(record: record),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonAvatar(
            name: record.pastoralName,
            photoUrl: record.pastorPhotoUrl,
            size: 42,
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.pastoralName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (record.confidentiality != CareConfidentiality.normal)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: record.confidentiality.color.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(AppTokens.pill),
                        ),
                        child: Text(
                          record.confidentiality.label,
                          style: TextStyle(
                            color: record.confidentiality.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(record.summary, style: const TextStyle(height: 1.35)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: AppTokens.space12,
                  runSpacing: 4,
                  children: [
                    _Fact(
                      icon: Icons.label_outline_rounded,
                      text: record.typeName,
                      color: record.typeColor,
                    ),
                    _Fact(
                      icon: Icons.event_outlined,
                      text: Formatters.relativeDateTime(record.occurredAt),
                      color: AppColors.mutedInk,
                    ),
                    if (record.performedByName != null)
                      _Fact(
                        icon: Icons.person_outline_rounded,
                        text: record.performedByName!,
                        color: AppColors.mutedInk,
                      ),
                    if (record.nextCareAt != null)
                      _Fact(
                        icon: Icons.event_available_outlined,
                        text: 'Próximo: ${Formatters.date(record.nextCareAt!)}',
                        color: AppColors.primary,
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

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CareDetailSheet extends ConsumerWidget {
  const _CareDetailSheet({required this.record});

  final CareRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(careRecordProvider(record.id));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space24,
          0,
          AppTokens.space24,
          AppTokens.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.summary,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (record.confidentiality != CareConfidentiality.normal)
                  Text(
                    record.confidentiality.label,
                    style: TextStyle(
                      color: record.confidentiality.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                record.typeName,
                Formatters.relativeDateTime(record.occurredAt),
                ?record.performedByName,
              ].join(' · '),
              style: const TextStyle(color: AppColors.mutedInk),
            ),
            const SizedBox(height: AppTokens.space16),
            AsyncValueView(
              value: detail,
              onRetry: () => ref.invalidate(careRecordProvider(record.id)),
              loading: const Skeleton(height: 70),
              data: (full) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    full.notes == null || full.notes!.isEmpty
                        ? 'Sem anotações.'
                        : full.notes!,
                    style: const TextStyle(height: 1.5),
                  ),
                  if (full.nextAction != null) ...[
                    const SizedBox(height: AppTokens.space16),
                    Text(
                      'Próxima ação: ${full.nextAction}',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ],
                  if (full.location != null ||
                      full.durationMinutes != null) ...[
                    const SizedBox(height: AppTokens.space8),
                    Text(
                      [
                        ?full.location,
                        if (full.durationMinutes != null)
                          '${full.durationMinutes} min',
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space24),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.go('/pastors/${record.pastorId}');
              },
              icon: const Icon(Icons.person_outline_rounded),
              label: const Text('Abrir perfil do pastor'),
            ),
          ],
        ),
      ),
    );
  }
}
