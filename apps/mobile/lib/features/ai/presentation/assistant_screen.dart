import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../data/ai_providers.dart';
import '../domain/ai_models.dart';

class AssistantScreen extends ConsumerWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final size = context.windowSize;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(copilotProvider),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          size.pagePadding,
          size.pagePadding,
          size.pagePadding,
          AppTokens.space32,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Assistente pastoral', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppTokens.space4),
                  const Text('Ideias práticas para cuidar melhor da sua parte da rede.', style: TextStyle(color: AppColors.mutedInk)),
                  const SizedBox(height: AppTokens.space16),
                  AsyncValueView(
                    value: ref.watch(copilotProvider),
                    onRetry: () => ref.invalidate(copilotProvider),
                    loading: const Skeleton(height: 360, radius: AppTokens.radius16),
                    data: (result) => _CopilotContent(result: result),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopilotContent extends StatelessWidget {
  const _CopilotContent({required this.result});

  final CopilotResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          color: AppColors.softPrimary,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                child: Icon(Icons.auto_awesome_rounded, size: 20),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Leitura do momento', style: TextStyle(fontWeight: FontWeight.w800))),
                        _SourceChip(result: result),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space8),
                    Text(result.summary, style: const TextStyle(height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space20),
        const SectionHeader(title: 'Próximas ações sugeridas'),
        const SizedBox(height: AppTokens.space8),
        for (final suggestion in result.suggestions) ...[
          _SuggestionCard(suggestion: suggestion),
          const SizedBox(height: AppTokens.space12),
        ],
        AppCard(
          color: AppColors.background,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 19),
              const SizedBox(width: AppTokens.space8),
              Expanded(child: Text(result.disclaimer, style: const TextStyle(color: AppColors.mutedInk, fontSize: 12, height: 1.35))),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.result});

  final CopilotResult result;

  @override
  Widget build(BuildContext context) {
    final label = result.fromNvidia ? 'NVIDIA NIM' : 'Modo local';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space8, vertical: AppTokens.space4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(AppTokens.pill)),
      child: Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion});

  final CopilotSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (suggestion.priority) {
      'alta' => AppColors.alert,
      'baixa' => AppColors.mutedInk,
      _ => AppColors.accent,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: priorityColor),
              const SizedBox(width: AppTokens.space8),
              Expanded(child: Text(suggestion.title, style: const TextStyle(fontWeight: FontWeight.w800))),
              Text(suggestion.priority, style: TextStyle(color: priorityColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppTokens.space8),
          Text(suggestion.description, style: const TextStyle(color: AppColors.mutedInk, height: 1.35)),
          const SizedBox(height: AppTokens.space12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => context.go(suggestion.actionPath),
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: Text(suggestion.actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
