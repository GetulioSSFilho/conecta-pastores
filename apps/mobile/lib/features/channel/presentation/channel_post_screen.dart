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
import '../data/channel_providers.dart';

/// Publicacao completa. Registra leitura ao abrir e permite confirmar ciencia.
class ChannelPostScreen extends ConsumerStatefulWidget {
  const ChannelPostScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<ChannelPostScreen> createState() => _ChannelPostScreenState();
}

class _ChannelPostScreenState extends ConsumerState<ChannelPostScreen> {
  var _acknowledging = false;

  @override
  void initState() {
    super.initState();
    // Leitura registrada ao abrir; confirmacao de ciencia continua sendo explicita.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(markPostReadProvider)(widget.postId);
      } catch (_) {
        // Falha ao marcar leitura nao impede ler a publicacao.
      }
    });
  }

  Future<void> _acknowledge() async {
    setState(() => _acknowledging = true);
    try {
      await ref.read(markPostReadProvider)(widget.postId, acknowledged: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leitura confirmada. Obrigado!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _acknowledging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final post = ref.watch(channelPostProvider(widget.postId));
    final canSeeStats =
        ref.watch(currentUserProvider)?.can('channel.read_stats') ?? false;
    final feedItem = ref
        .watch(channelFeedProvider)
        .value
        ?.items
        .where((p) => p.id == widget.postId)
        .firstOrNull;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        padding,
        AppTokens.space8,
        padding,
        AppTokens.space32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/channel'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Canal'),
                  ),
                ),
                const SizedBox(height: AppTokens.space8),
                AsyncValueView(
                  value: post,
                  onRetry: () =>
                      ref.invalidate(channelPostProvider(widget.postId)),
                  loading: const SkeletonCard(lines: 6),
                  data: (p) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(p.type.icon, size: 18, color: p.type.color),
                          const SizedBox(width: 6),
                          Text(
                            p.type.label,
                            style: TextStyle(
                              color: p.type.color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (p.isPinned) ...[
                            const SizedBox(width: AppTokens.space8),
                            const Icon(
                              Icons.push_pin_rounded,
                              size: 16,
                              color: AppColors.mutedInk,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppTokens.space12),
                      Text(
                        p.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                      ),
                      const SizedBox(height: AppTokens.space8),
                      Text(
                        [
                          ?p.authorName,
                          if (p.publishedAt != null)
                            'Publicado ${Formatters.relativeDateTime(p.publishedAt!)}',
                          if (p.expiresAt != null)
                            'Válido até ${Formatters.date(p.expiresAt!)}',
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.mutedInk),
                      ),
                      if (p.coverUrl != null) ...[
                        const SizedBox(height: AppTokens.space16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTokens.radius16,
                          ),
                          child: Image.network(
                            p.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppTokens.space16),
                      SelectionArea(
                        child: Text(
                          p.content,
                          style: const TextStyle(height: 1.6, fontSize: 15),
                        ),
                      ),
                      if (p.videoUrl != null) ...[
                        const SizedBox(height: AppTokens.space16),
                        FilledButton.icon(
                          onPressed: () =>
                              ContactActions.openLink(context, p.videoUrl!),
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: const Text('Assistir ao vídeo'),
                        ),
                      ],
                      if (p.requiresAck) ...[
                        const SizedBox(height: AppTokens.space24),
                        _AckCard(
                          acknowledged: feedItem?.acknowledged ?? false,
                          loading: _acknowledging,
                          onConfirm: _acknowledge,
                        ),
                      ],
                      if (canSeeStats) ...[
                        const SizedBox(height: AppTokens.space16),
                        AppCard(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.insights_outlined,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppTokens.space12),
                              Expanded(
                                child: Text(
                                  'Enviado para ${p.audienceCount} ${p.audienceCount == 1 ? 'pastor' : 'pastores'} · '
                                  '${p.readCount} ${p.readCount == 1 ? 'visualizou' : 'visualizaram'} · '
                                  '${p.pendingReads} ainda não ${p.pendingReads == 1 ? 'visualizou' : 'visualizaram'}',
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (p.audienceLabels.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppTokens.space8,
                            ),
                            child: Text(
                              'Público: ${p.audienceLabels.toSet().join(', ')}',
                              style: const TextStyle(
                                color: AppColors.mutedInk,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AckCard extends StatelessWidget {
  const _AckCard({
    required this.acknowledged,
    required this.loading,
    required this.onConfirm,
  });

  final bool acknowledged;
  final bool loading;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: acknowledged ? const Color(0xFFE7F7F2) : AppColors.softOrange,
      child: Row(
        children: [
          Icon(
            acknowledged
                ? Icons.verified_rounded
                : Icons.assignment_turned_in_outlined,
            color: acknowledged ? AppColors.success : AppColors.accent,
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Text(
              acknowledged
                  ? 'Você confirmou a leitura deste comunicado.'
                  : 'Este comunicado pede confirmação de leitura.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (!acknowledged)
            FilledButton(
              onPressed: loading ? null : onConfirm,
              child: Text(loading ? 'Confirmando...' : 'Confirmar leitura'),
            ),
        ],
      ),
    );
  }
}
