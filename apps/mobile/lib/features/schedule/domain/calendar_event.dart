import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Tipos de compromisso (EventType da API).
enum CalendarEventType {
  careMeeting(
    'CARE_MEETING',
    'Acompanhamento',
    Icons.volunteer_activism_outlined,
    AppColors.secondary,
  ),
  meeting('MEETING', 'Reunião', Icons.groups_2_outlined, AppColors.primary),
  visit('VISIT', 'Visita', Icons.home_outlined, AppColors.accent),
  course('COURSE', 'Curso', Icons.menu_book_outlined, AppColors.softPurple),
  training('TRAINING', 'Treinamento', Icons.school_outlined, AppColors.success),
  congress(
    'CONGRESS',
    'Congresso',
    Icons.celebration_outlined,
    AppColors.accent,
  ),
  service('SERVICE', 'Culto', Icons.church_outlined, AppColors.primary),
  conference(
    'CONFERENCE',
    'Conferência',
    Icons.campaign_outlined,
    AppColors.secondary,
  ),
  trip('TRIP', 'Viagem', Icons.flight_takeoff_rounded, AppColors.neutral),
  mission('MISSION', 'Missão', Icons.public_rounded, AppColors.success),
  other('OTHER', 'Outro', Icons.event_outlined, AppColors.neutral);

  const CalendarEventType(this.apiValue, this.label, this.icon, this.color);

  final String apiValue;
  final String label;
  final IconData icon;
  final Color color;

  static CalendarEventType fromApi(String? value) =>
      CalendarEventType.values.firstWhere(
        (t) => t.apiValue == value,
        orElse: () => CalendarEventType.other,
      );
}

class EventParticipant {
  const EventParticipant({
    required this.name,
    required this.status,
    this.pastorId,
  });

  factory EventParticipant.fromJson(Map<String, dynamic> json) {
    final pastor = (json['pastor'] as Map?)?.cast<String, dynamic>();
    return EventParticipant(
      pastorId: pastor?['id'] as String?,
      name: pastor?['pastoralName'] as String? ?? 'Participante',
      status: json['status'] as String? ?? 'INVITED',
    );
  }

  final String? pastorId;
  final String name;
  final String status;
}

/// Compromisso da agenda (`GET /events`). Horarios chegam em UTC e sao exibidos no local.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.allDay,
    required this.isOnline,
    this.description,
    this.location,
    this.meetingUrl,
    this.churchName,
    this.participants = const [],
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'] as String,
    type: CalendarEventType.fromApi(json['type'] as String?),
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    location: json['location'] as String?,
    isOnline: json['isOnline'] as bool? ?? false,
    meetingUrl: json['meetingUrl'] as String?,
    startsAt: DateTime.parse(json['startsAt'] as String).toLocal(),
    endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
    allDay: json['allDay'] as bool? ?? false,
    churchName:
        ((json['church'] as Map?)?.cast<String, dynamic>())?['name'] as String?,
    participants: [
      for (final p
          in (json['participants'] as List? ?? const [])
              .cast<Map<String, dynamic>>())
        EventParticipant.fromJson(p),
    ],
  );

  final String id;
  final CalendarEventType type;
  final String title;
  final String? description;
  final String? location;
  final bool isOnline;
  final String? meetingUrl;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String? churchName;
  final List<EventParticipant> participants;

  bool get isPast => endsAt.isBefore(DateTime.now());

  bool occursOn(DateTime day) {
    final start = DateTime(startsAt.year, startsAt.month, startsAt.day);
    final end = DateTime(endsAt.year, endsAt.month, endsAt.day);
    final target = DateTime(day.year, day.month, day.day);
    return !target.isBefore(start) && !target.isAfter(end);
  }

  /// Local legivel: online, endereco ou igreja.
  String? get place => isOnline ? 'Online' : (location ?? churchName);
}
