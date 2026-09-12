import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure_message.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/contact_actions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../data/training_providers.dart';
import '../domain/training_models.dart';

/// Formação em detalhe: conteúdo, módulos e a minha matrícula.
class TrainingDetailScreen extends ConsumerStatefulWidget {
  const TrainingDetailScreen({super.key, required this.trainingId});

  final String trainingId;

  @override
  ConsumerState<TrainingDetailScreen> createState() => _TrainingDetailScreenState();
}

class _TrainingDetailScreenState extends ConsumerState<TrainingDetailScreen> {
  bool _working = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final detail = ref.watch(trainingDetailProvider(widget.trainingId));
    final canEnroll = ref.watch(currentUserProvider)?.can('training.enroll') ?? false;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: EdgeInsets.fromLTRB(padding, padding, padding, AppTokens.space32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/training'),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Formação'),
              ),
            ),
            const SizedBox(height: AppTokens.space8),
            AsyncValueView(
              value: detail,
              onRetry: () => ref.invalidate(trainingDetailProvider(widget.trainingId)),
              loading: const SkeletonCard(lines: 6),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    detail: data,
                    working: _working,
                    canEnroll: canEnroll,
                    onEnroll: () => _run(
                      () => ref.read(trainingActionsProvider).enroll(widget.trainingId),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space16),
                  _Modules(
                    detail: data,
                    working: _working,
                    onToggle: (module, completed) {
                      final enrollment = data.myEnrollment;
                      if (enrollment == null) return;
                      _run(
                        () => ref
                            .read(trainingActionsProvider)
                            .markModule(
                              trainingId: widget.trainingId,
                              enrollmentId: enrollment.id,
                              moduleId: module.id,
                              completed: completed,
                            ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.detail,
    required this.working,
    required this.canEnroll,
    required this.onEnroll,
  });

  final TrainingDetail detail;
  final bool working;
  final bool canEnroll;
  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) {
    final training = detail.training;
    final enrollment = detail.myEnrollment;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
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
                    Text(
                      training.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        training.code,
                        training.kind.label,
                        training.workloadText,
                        if (training.isMandatory) 'Obrigatório',
                      ].join(' · '),
                      style: const TextStyle(color: AppColors.mutedInk),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (training.summary != null) ...[
            const SizedBox(height: AppTokens.space12),
            Text(training.summary!, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (training.description != null) ...[
            const SizedBox(height: AppTokens.space8),
            Text(training.description!, style: const TextStyle(color: AppColors.mutedInk)),
          ],
          const Divider(height: AppTokens.space24),
          if (enrollment != null) ...[
            Row(
              children: [
                Text(
                  enrollment.status.label,
                  style: TextStyle(color: enrollment.status.color, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '${enrollment.progressPct}% concluído',
                  style: const TextStyle(color: AppColors.mutedInk),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: enrollment.progressPct / 100,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(enrollment.status.color),
              ),
            ),
            const SizedBox(height: AppTokens.space8),
            Text(
              [
                if (enrollment.enrolledAt != null)
                  'Matrícula em ${Formatters.date(enrollment.enrolledAt!)}',
                if (enrollment.completedAt != null)
                  'Concluída em ${Formatters.date(enrollment.completedAt!)}',
                if (enrollment.score != null) 'Nota ${enrollment.score}',
              ].join(' · '),
              style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
            ),
          ] else if (canEnroll)
            FilledButton.icon(
              onPressed: working ? null : onEnroll,
              icon: const Icon(Icons.how_to_reg_rounded),
              label: const Text('Matricular-me'),
            )
          else
            const Text(
              'Você não está matriculado nesta formação.',
              style: TextStyle(color: AppColors.mutedInk),
            ),
        ],
      ),
    );
  }
}

class _Modules extends StatelessWidget {
  const _Modules({required this.detail, required this.working, required this.onToggle});

  final TrainingDetail detail;
  final bool working;
  final void Function(TrainingModule module, bool completed) onToggle;

  @override
  Widget build(BuildContext context) {
    if (detail.modules.isEmpty) return const SizedBox.shrink();
    final done = detail.modules.where((m) => m.completed).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Módulos (${detail.modules.length})',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '$done de ${detail.modules.length} marcados como concluídos',
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
          const SizedBox(height: AppTokens.space8),
          for (final module in detail.modules)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(module.icon, color: AppColors.primary),
              title: Text(module.title),
              subtitle: Text(
                [
                  module.contentType,
                  if (module.durationMinutes != null) '${module.durationMinutes} min',
                  if (!module.isRequired) 'Opcional',
                ].join(' · '),
              ),
              trailing: detail.isEnrolled
                  ? Checkbox(
                      value: module.completed,
                      onChanged: working
                          ? null
                          : (value) => onToggle(module, value ?? false),
                    )
                  : module.contentUrl == null
                  ? null
                  : IconButton(
                      tooltip: 'Abrir conteúdo',
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      onPressed: () => ContactActions.openLink(context, module.contentUrl!),
                    ),
            ),
        ],
      ),
    );
  }
}
