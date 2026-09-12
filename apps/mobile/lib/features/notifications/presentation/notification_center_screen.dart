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
import '../../../core/widgets/paged_list_view.dart';
import '../data/notifications_providers.dart';
import '../domain/app_notification.dart';

/// Caixa de entrada de notificacoes internas.
///
/// Independente de push: a persistencia e no PostgreSQL, o push (quando houver)
/// e apenas um complemento.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    try {
      await ref.read(notificationsProvider.notifier).markRead(notification);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
    final link = notification.link;
    if (link != null && link.startsWith('/') && context.mounted) {
      context.go(link);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = context.windowSize.pagePadding;
    final query = ref.watch(notificationQueryProvider);
    final unread = ref.watch(unreadNotificationsCountProvider).value ?? 0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
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
                          'Notificações',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          unread == 0
                              ? 'Tudo lido'
                              : '$unread não ${unread == 1 ? 'lida' : 'lidas'}',
                          style: const TextStyle(color: AppColors.mutedInk),
                        ),
                      ],
                    ),
                  ),
                  if (unread > 0)
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await ref
                              .read(notificationsProvider.notifier)
                              .markAllRead();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(errorMessage(e))),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.done_all_rounded),
                      label: const Text('Marcar todas como lidas'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                padding,
                AppTokens.space12,
                padding,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Todas')),
                    ButtonSegment(value: true, label: Text('Não lidas')),
                  ],
                  selected: {query.unreadOnly},
                  onSelectionChanged: (s) => ref
                      .read(notificationQueryProvider.notifier)
                      .set(query.copyWith(unreadOnly: s.first)),
                ),
              ),
            ),
            Expanded(
              child: PagedListView(
                value: ref.watch(notificationsProvider),
                padding: EdgeInsets.fromLTRB(
                  padding,
                  AppTokens.space16,
                  padding,
                  AppTokens.space32,
                ),
                onLoadMore: () =>
                    ref.read(notificationsProvider.notifier).loadMore(),
                onRetry: () => ref.invalidate(notificationsProvider),
                onRefresh: () async {
                  ref
                    ..invalidate(notificationsProvider)
                    ..invalidate(unreadNotificationsCountProvider);
                },
                empty: InlineEmpty(
                  icon: query.unreadOnly
                      ? Icons.mark_email_read_outlined
                      : Icons.notifications_none_rounded,
                  message: query.unreadOnly
                      ? 'Nenhuma notificação não lida.'
                      : 'Você ainda não recebeu notificações.',
                ),
                itemBuilder: (context, item) => _NotificationTile(
                  notification: item,
                  onTap: () => _open(context, ref, item),
                  onDelete: () async {
                    try {
                      await ref
                          .read(notificationsProvider.notifier)
                          .remove(item);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(errorMessage(e))),
                        );
                      }
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTokens.space24),
        decoration: BoxDecoration(
          color: AppColors.alert.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTokens.radius16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.alert),
      ),
      onDismissed: (_) => onDelete(),
      child: AppCard(
        onTap: onTap,
        color: unread ? AppColors.softPrimary : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: notification.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTokens.radius12),
              ),
              child: Icon(
                notification.icon,
                size: 20,
                color: notification.color,
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (unread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: const TextStyle(color: AppColors.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${notification.typeLabel} · ${Formatters.relativeDateTime(notification.createdAt)}',
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remover',
              onPressed: onDelete,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
