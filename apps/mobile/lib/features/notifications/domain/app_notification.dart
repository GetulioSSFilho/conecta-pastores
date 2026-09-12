import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Notificacao interna (`GET /notifications`), independente de push externo.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.link,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'SYSTEM',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        link: json['link'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        readAt: json['readAt'] is String
            ? DateTime.tryParse(json['readAt'] as String)
            : null,
      );

  final String id;
  final String type;
  final String title;
  final String body;
  final String? link;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    link: link,
    createdAt: createdAt,
    readAt: readAt ?? this.readAt,
  );

  String get typeLabel => switch (type) {
    'CHANNEL_POST' => 'Comunicado',
    'PASTORAL_CARE' => 'Cuidado pastoral',
    'REQUEST' => 'Solicitação',
    'EVENT' => 'Agenda',
    'DOCUMENT' => 'Documento',
    'TRAINING' => 'Formação',
    _ => 'Sistema',
  };

  IconData get icon => switch (type) {
    'CHANNEL_POST' => Icons.campaign_outlined,
    'PASTORAL_CARE' => Icons.volunteer_activism_outlined,
    'REQUEST' => Icons.support_agent_outlined,
    'EVENT' => Icons.calendar_month_outlined,
    'DOCUMENT' => Icons.folder_outlined,
    'TRAINING' => Icons.school_outlined,
    _ => Icons.notifications_none_rounded,
  };

  Color get color => switch (type) {
    'CHANNEL_POST' => AppColors.primary,
    'PASTORAL_CARE' => AppColors.secondary,
    'REQUEST' => AppColors.accent,
    'EVENT' => AppColors.primary,
    'DOCUMENT' => AppColors.neutral,
    'TRAINING' => AppColors.success,
    _ => AppColors.neutral,
  };
}
