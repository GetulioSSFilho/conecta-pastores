import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paginated.dart';
import '../domain/calendar_event.dart';

/// Mes exibido no calendario (primeiro dia do mes, hora local).
class VisibleMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void next() => state = DateTime(state.year, state.month + 1);
  void previous() => state = DateTime(state.year, state.month - 1);
  void today() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month);
  }
}

final visibleMonthProvider =
    NotifierProvider.autoDispose<VisibleMonthNotifier, DateTime>(
      VisibleMonthNotifier.new,
    );

/// Dia selecionado no calendario (Riverpod 3 nao tem StateProvider fora do legacy).
class SelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void select(DateTime day) => state = DateTime(day.year, day.month, day.day);
}

final selectedDayProvider =
    NotifierProvider.autoDispose<SelectedDayNotifier, DateTime>(
      SelectedDayNotifier.new,
    );

/// Eventos do mes visivel (uma consulta por mes, faixa enviada ao servidor).
final monthEventsProvider = FutureProvider.autoDispose<List<CalendarEvent>>((
  ref,
) async {
  final month = ref.watch(visibleMonthProvider);
  final from = DateTime(
    month.year,
    month.month,
  ).subtract(const Duration(days: 7));
  final to = DateTime(month.year, month.month + 1).add(const Duration(days: 7));
  final json = await ref
      .watch(apiClientProvider)
      .getJson(
        '/events',
        query: {
          'from': from.toUtc(),
          'to': to.toUtc(),
          'pageSize': 100,
          'sortOrder': 'asc',
        },
      );
  return Paginated.fromJson(json, CalendarEvent.fromJson).items;
});

/// Proximos compromissos do usuario (a partir de agora).
final upcomingEventsProvider = FutureProvider.autoDispose<List<CalendarEvent>>((
  ref,
) async {
  final json = await ref
      .watch(apiClientProvider)
      .getJson(
        '/events',
        query: {
          'from': DateTime.now().toUtc(),
          'pageSize': 20,
          'sortOrder': 'asc',
        },
      );
  return Paginated.fromJson(json, CalendarEvent.fromJson).items;
});

final eventDetailProvider = FutureProvider.autoDispose
    .family<CalendarEvent, String>((ref, id) async {
      return CalendarEvent.fromJson(
        await ref.watch(apiClientProvider).getJson('/events/$id'),
      );
    });

/// Dados de criacao de compromisso (POST /events).
class NewEvent {
  const NewEvent({
    required this.type,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    this.description,
    this.location,
    this.isOnline = false,
    this.meetingUrl,
    this.pastorIds = const [],
  });

  final CalendarEventType type;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? description;
  final String? location;
  final bool isOnline;
  final String? meetingUrl;
  final List<String> pastorIds;

  Map<String, dynamic> toApi() => {
    'type': type.apiValue,
    // MVP: compromissos criados pelo app sao individuais (com participantes).
    'scope': 'INDIVIDUAL',
    'title': title.trim(),
    if (description != null && description!.trim().isNotEmpty)
      'description': description!.trim(),
    if (!isOnline && location != null && location!.trim().isNotEmpty)
      'location': location!.trim(),
    'isOnline': isOnline,
    if (isOnline && meetingUrl != null && meetingUrl!.trim().isNotEmpty)
      'meetingUrl': meetingUrl!.trim(),
    'startsAt': startsAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
    'timezone': DateTime.now().timeZoneName,
    if (pastorIds.isNotEmpty) 'pastorIds': pastorIds,
  };
}

final createEventProvider = Provider<Future<String> Function(NewEvent)>((ref) {
  return (NewEvent event) async {
    final created = await ref
        .read(apiClientProvider)
        .post('/events', body: event.toApi());
    ref
      ..invalidate(monthEventsProvider)
      ..invalidate(upcomingEventsProvider);
    return (created as Map?)?['id'] as String? ?? '';
  };
});
