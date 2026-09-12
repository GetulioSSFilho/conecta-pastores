import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Tipos de publicacao do Canal (PostType da API).
enum ChannelPostType {
  announcement(
    'ANNOUNCEMENT',
    'Comunicado',
    Icons.campaign_outlined,
    AppColors.primary,
  ),
  news('NEWS', 'Notícia', Icons.newspaper_outlined, AppColors.secondary),
  devotional(
    'DEVOTIONAL',
    'Devocional',
    Icons.menu_book_outlined,
    AppColors.softPurple,
  ),
  video('VIDEO', 'Vídeo', Icons.play_circle_outline_rounded, AppColors.primary),
  document(
    'DOCUMENT',
    'Documento',
    Icons.description_outlined,
    AppColors.neutral,
  ),
  event('EVENT', 'Evento', Icons.event_outlined, AppColors.accent),
  urgent(
    'URGENT',
    'Aviso urgente',
    Icons.priority_high_rounded,
    AppColors.alert,
  );

  const ChannelPostType(this.apiValue, this.label, this.icon, this.color);

  final String apiValue;
  final String label;
  final IconData icon;
  final Color color;

  static ChannelPostType fromApi(String? value) =>
      ChannelPostType.values.firstWhere(
        (t) => t.apiValue == value,
        orElse: () => ChannelPostType.announcement,
      );
}

/// Publicacao do Canal em listagens (`GET /channel`).
class ChannelPostSummary {
  const ChannelPostSummary({
    required this.id,
    required this.type,
    required this.title,
    required this.isPinned,
    required this.requiresAck,
    this.summary,
    this.coverUrl,
    this.publishedAt,
    this.authorName,
    this.readAt,
    this.acknowledged = false,
    this.readCount = 0,
  });

  factory ChannelPostSummary.fromJson(Map<String, dynamic> json) {
    final author = (json['author'] as Map?)?.cast<String, dynamic>();
    final read = (json['read'] as Map?)?.cast<String, dynamic>();
    return ChannelPostSummary(
      id: json['id'] as String,
      type: ChannelPostType.fromApi(json['type'] as String?),
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String?,
      coverUrl: json['coverUrl'] as String?,
      isPinned: json['isPinned'] as bool? ?? false,
      requiresAck: json['requiresAck'] as bool? ?? false,
      publishedAt: json['publishedAt'] is String
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
      authorName: author == null
          ? null
          : '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}'.trim(),
      readAt: read?['readAt'] is String
          ? DateTime.tryParse(read!['readAt'] as String)
          : null,
      acknowledged: read?['acknowledgedAt'] != null,
      readCount: (json['readCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final ChannelPostType type;
  final String title;
  final String? summary;
  final String? coverUrl;
  final bool isPinned;
  final bool requiresAck;
  final DateTime? publishedAt;
  final String? authorName;
  final DateTime? readAt;
  final bool acknowledged;
  final int readCount;

  bool get isRead => readAt != null;

  /// Comunicado que exige ciencia e ainda nao confirmado.
  bool get needsAck => requiresAck && !acknowledged;

  ChannelPostSummary copyWith({DateTime? readAt, bool? acknowledged}) =>
      ChannelPostSummary(
        id: id,
        type: type,
        title: title,
        summary: summary,
        coverUrl: coverUrl,
        isPinned: isPinned,
        requiresAck: requiresAck,
        publishedAt: publishedAt,
        authorName: authorName,
        readAt: readAt ?? this.readAt,
        acknowledged: acknowledged ?? this.acknowledged,
        readCount: readCount,
      );

  String get typeLabel => type.label;
}

/// Publicacao completa (`GET /channel/:id`).
class ChannelPostDetail {
  const ChannelPostDetail({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.isPinned,
    required this.requiresAck,
    required this.audienceCount,
    required this.readCount,
    this.summary,
    this.coverUrl,
    this.videoUrl,
    this.publishedAt,
    this.expiresAt,
    this.authorName,
    this.audienceLabels = const [],
  });

  factory ChannelPostDetail.fromJson(Map<String, dynamic> json) {
    final author = (json['author'] as Map?)?.cast<String, dynamic>();
    return ChannelPostDetail(
      id: json['id'] as String,
      type: ChannelPostType.fromApi(json['type'] as String?),
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String?,
      content: json['content'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      isPinned: json['isPinned'] as bool? ?? false,
      requiresAck: json['requiresAck'] as bool? ?? false,
      publishedAt: json['publishedAt'] is String
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
      expiresAt: json['expiresAt'] is String
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      authorName: author == null
          ? null
          : '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}'.trim(),
      audienceCount: (json['audienceCount'] as num?)?.toInt() ?? 0,
      readCount: (json['readCount'] as num?)?.toInt() ?? 0,
      audienceLabels: [
        for (final a
            in (json['audiences'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          switch (a['type'] as String?) {
            'ALL' => 'Todos os pastores',
            'COUNTRY' => 'Por país',
            'REGION' => 'Por região',
            'CHURCH' => 'Por igreja',
            'MINISTRY_ROLE' => 'Por função ministerial',
            'SUBTREE' => 'Por rede',
            'USER' => 'Pessoas específicas',
            _ => 'Segmentado',
          },
      ],
    );
  }

  final String id;
  final ChannelPostType type;
  final String title;
  final String? summary;
  final String content;
  final String? coverUrl;
  final String? videoUrl;
  final bool isPinned;
  final bool requiresAck;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final String? authorName;
  final int audienceCount;
  final int readCount;
  final List<String> audienceLabels;

  int get pendingReads => (audienceCount - readCount).clamp(0, audienceCount);
}
