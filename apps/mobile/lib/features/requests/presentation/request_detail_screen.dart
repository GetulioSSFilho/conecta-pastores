import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure_message.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../data/requests_providers.dart';
import '../domain/request_models.dart';

/// Detalhe da solicitacao com linha do tempo, comentarios e mudanca de situacao.
class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  final _comment = TextEditingController();
  var _sending = false;
  var _internal = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _sending = true);
    try {
      await action();
      if (success != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _changeStatus(
    RequestDetail request,
    RequestStatusKind target,
  ) async {
    var resolution = '';
    if (target == RequestStatusKind.resolved) {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Resolver solicitação'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'O que foi feito?',
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Resolver'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      resolution = controller.text;
    }
    await _run(
      () => ref
          .read(requestActionsProvider)
          .changeStatus(request.id, target, resolution: resolution),
      success: 'Situação atualizada para ${target.label.toLowerCase()}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final user = ref.watch(currentUserProvider);
    final detail = ref.watch(requestDetailProvider(widget.requestId));
    final canManage = user?.can('request.assign') ?? false;
    final canResolve = user?.can('request.resolve') ?? false;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            padding,
            AppTokens.space8,
            padding,
            AppTokens.space32,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/requests'),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Solicitações'),
              ),
            ),
            const SizedBox(height: AppTokens.space8),
            AsyncValueView(
              value: detail,
              onRetry: () =>
                  ref.invalidate(requestDetailProvider(widget.requestId)),
              loading: const SkeletonCard(lines: 5),
              data: (request) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '#${request.number}',
                              style: const TextStyle(
                                color: AppColors.mutedInk,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: AppTokens.space8),
                            _Tag(
                              label: request.status.label,
                              color: request.status.color,
                            ),
                            const SizedBox(width: AppTokens.space8),
                            _Tag(
                              label: request.priority.label,
                              color: request.priority.color,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.space12),
                        Text(
                          request.subject,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppTokens.space8),
                        Text(
                          [
                            ?request.categoryName,
                            if (request.requesterName != null)
                              'Aberta por ${request.requesterName}',
                            Formatters.relativeDateTime(request.createdAt),
                          ].join(' · '),
                          style: const TextStyle(
                            color: AppColors.mutedInk,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: AppTokens.space16),
                        Text(
                          request.description,
                          style: const TextStyle(height: 1.5),
                        ),
                        if (request.resolution != null) ...[
                          const SizedBox(height: AppTokens.space16),
                          Container(
                            padding: const EdgeInsets.all(AppTokens.space12),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(
                                AppTokens.radius12,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Resolução',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(request.resolution!),
                              ],
                            ),
                          ),
                        ],
                        const Divider(height: AppTokens.space32),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 18,
                              color: AppColors.mutedInk,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                request.assigneeName == null
                                    ? 'Ainda sem responsável'
                                    : 'Responsável: ${request.assigneeName}',
                                style: const TextStyle(
                                  color: AppColors.mutedInk,
                                ),
                              ),
                            ),
                            if (canManage && request.assigneeId == null)
                              TextButton.icon(
                                onPressed: _sending
                                    ? null
                                    : () => _run(
                                        () => ref
                                            .read(requestActionsProvider)
                                            .assignToMe(request.id),
                                        success:
                                            'Você assumiu esta solicitação.',
                                      ),
                                icon: const Icon(
                                  Icons.assignment_ind_outlined,
                                  size: 18,
                                ),
                                label: const Text('Assumir'),
                              ),
                          ],
                        ),
                        if (canResolve &&
                            request.status.nextOptions.isNotEmpty) ...[
                          const SizedBox(height: AppTokens.space12),
                          Wrap(
                            spacing: AppTokens.space8,
                            runSpacing: AppTokens.space8,
                            children: [
                              for (final next in request.status.nextOptions)
                                OutlinedButton(
                                  onPressed: _sending
                                      ? null
                                      : () => _changeStatus(request, next),
                                  child: Text(next.label),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Histórico',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppTokens.space12),
                        for (final entry in request.timeline)
                          _TimelineTile(entry: entry),
                        const Divider(height: AppTokens.space32),
                        TextField(
                          controller: _comment,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Escrever comentário',
                            alignLabelWithHint: true,
                          ),
                        ),
                        if (canManage)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _internal,
                            onChanged: (v) =>
                                setState(() => _internal = v ?? false),
                            title: const Text('Nota interna'),
                            subtitle: const Text(
                              'Visível apenas para quem atende a solicitação.',
                            ),
                          ),
                        const SizedBox(height: AppTokens.space8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _sending || _comment.text.trim().isEmpty
                                ? null
                                : () => _run(() async {
                                    await ref
                                        .read(requestActionsProvider)
                                        .comment(
                                          request.id,
                                          _comment.text,
                                          internal: _internal,
                                        );
                                    _comment.clear();
                                  }, success: 'Comentário enviado.'),
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: Text(_sending ? 'Enviando...' : 'Enviar'),
                          ),
                        ),
                      ],
                    ),
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

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.entry});

  final RequestTimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: entry.isInternal
                  ? AppColors.softOrange
                  : AppColors.softPrimary,
              borderRadius: BorderRadius.circular(AppTokens.radius8),
            ),
            child: Icon(
              entry.icon,
              size: 16,
              color: entry.isInternal ? AppColors.accent : AppColors.primary,
            ),
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
                        [
                          ?entry.authorName,
                          Formatters.relativeDateTime(entry.createdAt),
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (entry.isInternal)
                      const Text(
                        'Interna',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                if (entry.message != null) ...[
                  const SizedBox(height: 2),
                  Text(entry.message!, style: const TextStyle(height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTokens.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
