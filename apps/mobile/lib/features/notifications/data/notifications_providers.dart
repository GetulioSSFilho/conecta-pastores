import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paged_controller.dart';
import '../../../core/api/paginated.dart';
import '../domain/app_notification.dart';

/// Contador do sino. Invalidado ao ler notificacoes e no pull-to-refresh.
final unreadNotificationsCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final data = await ref
      .watch(apiClientProvider)
      .getJson('/notifications/unread-count');
  return (data['count'] as num?)?.toInt() ?? 0;
});

/// Filtro da caixa de entrada (aplicado no servidor).
class NotificationQuery {
  const NotificationQuery({this.unreadOnly = false, this.type});

  final bool unreadOnly;
  final String? type;

  NotificationQuery copyWith({bool? unreadOnly, String? Function()? type}) =>
      NotificationQuery(
        unreadOnly: unreadOnly ?? this.unreadOnly,
        type: type != null ? type() : this.type,
      );

  Map<String, dynamic> toApi(int page) => {
    'page': page,
    'pageSize': 25,
    if (unreadOnly) 'unreadOnly': true,
    'type': type,
  };
}

class NotificationQueryNotifier extends Notifier<NotificationQuery> {
  @override
  NotificationQuery build() => const NotificationQuery();

  void set(NotificationQuery query) => state = query;
}

final notificationQueryProvider =
    NotifierProvider.autoDispose<NotificationQueryNotifier, NotificationQuery>(
      NotificationQueryNotifier.new,
    );

class NotificationsController extends PagedController<AppNotification> {
  @override
  Future<PagedResult<AppNotification>> build() {
    ref.watch(notificationQueryProvider);
    return super.build();
  }

  @override
  Future<Paginated<AppNotification>> fetchPage(int page) async {
    final json = await ref
        .read(apiClientProvider)
        .getJson(
          '/notifications',
          query: ref.read(notificationQueryProvider).toApi(page),
        );
    return Paginated.fromJson(json, AppNotification.fromJson);
  }

  /// Marca como lida otimisticamente: a lista reflete na hora e reverte em caso de erro.
  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    final before = state.value;
    _patch(notification.id, (n) => n.copyWith(readAt: DateTime.now()));
    try {
      await ref
          .read(apiClientProvider)
          .post('/notifications/${notification.id}/read');
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {
      if (before != null) state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    final before = state.value;
    final now = DateTime.now();
    if (before != null) {
      state = AsyncData(
        before.copyWith(
          items: [
            for (final n in before.items)
              n.isRead ? n : n.copyWith(readAt: now),
          ],
        ),
      );
    }
    try {
      await ref.read(apiClientProvider).post('/notifications/read-all');
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {
      if (before != null) state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> remove(AppNotification notification) async {
    final before = state.value;
    if (before != null) {
      state = AsyncData(
        before.copyWith(
          items: [...before.items.where((n) => n.id != notification.id)],
          total: before.total - 1,
        ),
      );
    }
    try {
      await ref
          .read(apiClientProvider)
          .delete('/notifications/${notification.id}');
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {
      if (before != null) state = AsyncData(before);
      rethrow;
    }
  }

  void _patch(String id, AppNotification Function(AppNotification) change) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [for (final n in current.items) n.id == id ? change(n) : n],
      ),
    );
  }
}

final notificationsProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationsController,
      PagedResult<AppNotification>
    >(NotificationsController.new);
