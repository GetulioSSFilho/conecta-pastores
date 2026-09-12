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
import '../../../core/api/api_client.dart';
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
                  Text(
                    'Assistente pastoral',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space4),
                  const Text(
                    'Ideias práticas para cuidar melhor da sua parte da rede.',
                    style: TextStyle(color: AppColors.mutedInk),
                  ),
                  const SizedBox(height: AppTokens.space16),
                  AsyncValueView(
                    value: ref.watch(copilotProvider),
                    onRetry: () => ref.invalidate(copilotProvider),
                    loading: const Skeleton(
                      height: 360,
                      radius: AppTokens.radius16,
                    ),
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

/// Assistente flutuante: conversa curta, com ações que podem abrir somente
/// rotas devolvidas pelo backend dentro das permissões do usuário.
class AiAssistantSheet extends ConsumerStatefulWidget {
  const AiAssistantSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    builder: (_) => const AiAssistantSheet(),
  );

  @override
  ConsumerState<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends ConsumerState<AiAssistantSheet> {
  final _input = TextEditingController();
  final _messages = <_AssistantMessage>[
    const _AssistantMessage(
      text:
          'Olá! Posso abrir uma área da aplicação ou ajudar a decidir o próximo passo da sua rotina.',
      fromUser: false,
    ),
  ];
  AiIntentResult? _lastIntent;
  var _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _messages.add(_AssistantMessage(text: text, fromUser: true));
      _lastIntent = null;
      _sending = true;
    });
    try {
      final json = await ref
          .read(apiClientProvider)
          .post('/ai/intent', body: {'message': text});
      final result = AiIntentResult.fromJson(
        json is Map ? json.cast<String, dynamic>() : const {},
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_AssistantMessage(text: result.reply, fromUser: false));
        _lastIntent = result;
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const _AssistantMessage(
            text:
                'Não consegui concluir agora. Tente novamente em alguns instantes.',
            fromUser: false,
          ),
        );
        _sending = false;
      });
    }
  }

  void _openIntent() {
    final path = _lastIntent?.actionPath;
    if (path == null) return;
    Navigator.of(context).pop();
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.auto_awesome_rounded, size: 19),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assistente pastoral',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Navegação e próximos passos',
                        style: TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 20),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                reverse: false,
                children: [
                  for (final message in _messages)
                    _MessageBubble(message: message),
                  if (_sending)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  if (!_sending && _lastIntent?.actionPath != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: OutlinedButton.icon(
                          onPressed: _openIntent,
                          icon: const Icon(Icons.open_in_new_rounded, size: 17),
                          label: const Text('Abrir tela sugerida'),
                        ),
                      ),
                    ),
                  if (_messages.length == 1 && !_sending)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final prompt in [
                          'Abrir minha agenda',
                          'Ver minha rede',
                          'O que priorizar hoje?',
                        ])
                          ActionChip(
                            label: Text(prompt),
                            onPressed: () => _send(prompt),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ex.: abrir meus acompanhamentos',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Enviar pedido',
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantMessage {
  const _AssistantMessage({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.fromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: message.fromUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          border: message.fromUser ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.fromUser ? Colors.white : AppColors.ink,
            height: 1.3,
          ),
        ),
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
                        const Expanded(
                          child: Text(
                            'Leitura do momento',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
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
              const Icon(
                Icons.verified_user_outlined,
                color: AppColors.primary,
                size: 19,
              ),
              const SizedBox(width: AppTokens.space8),
              Expanded(
                child: Text(
                  result.disclaimer,
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space8,
        vertical: AppTokens.space4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppTokens.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
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
              Expanded(
                child: Text(
                  suggestion.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                suggestion.priority,
                style: TextStyle(
                  color: priorityColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space8),
          Text(
            suggestion.description,
            style: const TextStyle(color: AppColors.mutedInk, height: 1.35),
          ),
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
