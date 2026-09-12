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
import '../../../core/widgets/skeleton.dart';
import '../data/training_providers.dart';
import '../domain/training_models.dart';

/// Formação: minhas matrículas e catálogo disponível.
class TrainingCatalogScreen extends ConsumerWidget {
  const TrainingCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = context.windowSize.pagePadding;
    final query = ref.watch(trainingQueryProvider);
    final notifier = ref.read(trainingQueryProvider.notifier);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Formação',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Cursos, trilhas e oficinas do ministério',
                    style: TextStyle(color: AppColors.mutedInk),
                  ),
                  const SizedBox(height: AppTokens.space16),
                  const _MyEnrollments(),
                  const SizedBox(height: AppTokens.space16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: !query.hasFilters,
                          onSelected: (_) => notifier.set(const TrainingQuery()),
                        ),
                        const SizedBox(width: AppTokens.space8),
                        FilterChip(
                          avatar: const Icon(
                            Icons.priority_high_rounded,
                            size: 18,
                            color: AppColors.accent,
                          ),
                          label: const Text('Obrigatórios'),
                          selected: query.onlyMandatory,
                          onSelected: (v) => notifier.update((q) => q.copyWith(onlyMandatory: v)),
                        ),
                        for (final kind in TrainingKind.values) ...[
                          const SizedBox(width: AppTokens.space8),
                          ChoiceChip(
                            avatar: Icon(kind.icon, size: 18),
                            label: Text(kind.label),
                            selected: query.kind == kind,
                            onSelected: (selected) => notifier.update(
                              (q) => q.copyWith(kind: () => selected ? kind : null),
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
                value: ref.watch(trainingCatalogProvider),
                padding: EdgeInsets.fromLTRB(
                  padding,
                  AppTokens.space16,
                  padding,
                  AppTokens.space32,
                ),
                onLoadMore: () => ref.read(trainingCatalogProvider.notifier).loadMore(),
                onRetry: () => ref.invalidate(trainingCatalogProvider),
                onRefresh: () async {
                  ref.invalidate(trainingCatalogProvider);
                  ref.invalidate(myEnrollmentsProvider);
                },
                empty: InlineEmpty(
                  icon: query.hasFilters ? Icons.filter_alt_off_outlined : Icons.school_outlined,
                  message: query.hasFilters
                      ? 'Nenhuma formação com esses filtros.'
                      : 'Nenhuma formação publicada.',
                  action: query.hasFilters
                      ? TextButton(
                          onPressed: () => notifier.set(const TrainingQuery()),
                          child: const Text('Limpar filtros'),
                        )
                      : null,
                ),
                itemBuilder: (context, training) => _TrainingCard(training: training),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minhas matrículas: some quando o usuário não é pastor ou não tem acesso.
class _MyEnrollments extends ConsumerWidget {
  const _MyEnrollments();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(myEnrollmentsProvider),
      hideWhenForbidden: true,
      onRetry: () => ref.invalidate(myEnrollmentsProvider),
      loading: const SkeletonCard(lines: 3),
      data: (enrollments) {
        if (enrollments.isEmpty) return const SizedBox.shrink();
        final concluidas = enrollments.where((e) => e.isCompleted).length;
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Minhas formações (${enrollments.length})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '$concluidas ${concluidas == 1 ? 'concluída' : 'concluídas'}',
                style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
              ),
              const SizedBox(height: AppTokens.space12),
              for (final enrollment in enrollments)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.space12),
                  child: _EnrollmentRow(enrollment: enrollment),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EnrollmentRow extends StatelessWidget {
  const _EnrollmentRow({required this.enrollment});

  final TrainingEnrollment enrollment;

  @override
  Widget build(BuildContext context) {
    final days = enrollment.daysUntilDue;
    final trainingId = enrollment.trainingId;

    return InkWell(
      onTap: trainingId == null ? null : () => context.go('/training/$trainingId'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  enrollment.trainingTitle ?? 'Formação',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                enrollment.status.label,
                style: TextStyle(
                  color: enrollment.status.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: enrollment.progressPct / 100,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(enrollment.status.color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              '${enrollment.progressPct}% concluído',
              if (enrollment.completedAt != null)
                'Concluído em ${Formatters.date(enrollment.completedAt!)}',
              if (days != null && days >= 0) 'Prazo em $days ${days == 1 ? 'dia' : 'dias'}',
              if (days != null && days < 0) 'Prazo venceu há ${-days} dias',
            ].join(' · '),
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({required this.training});

  final Training training;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.go('/training/${training.id}'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.softPrimary,
              borderRadius: BorderRadius.circular(AppTokens.radius12),
            ),
            child: Icon(training.kind.icon, color: AppColors.primary),
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
                        training.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (training.isMandatory) ...[
                      const SizedBox(width: AppTokens.space8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Obrigatório',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [training.code, training.kind.label, training.workloadText].join(' · '),
                  style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                ),
                if (training.summary != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    training.summary!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space8),
          if (training.isEnrolled)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  training.myEnrollment!.status.label,
                  style: TextStyle(
                    color: training.myEnrollment!.status.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${training.myEnrollment!.progressPct}%',
                  style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                ),
              ],
            )
          else
            const Icon(Icons.chevron_right_rounded, color: AppColors.mutedInk),
        ],
      ),
    );
  }
}
