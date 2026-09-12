import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Situacao da solicitacao (RequestStatus da API).
enum RequestStatusKind {
  open('OPEN', 'Aberta', AppColors.accent),
  inProgress('IN_PROGRESS', 'Em andamento', AppColors.primary),
  waiting('WAITING', 'Aguardando', AppColors.neutral),
  resolved('RESOLVED', 'Resolvida', AppColors.success),
  closed('CLOSED', 'Encerrada', AppColors.neutral);

  const RequestStatusKind(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  static RequestStatusKind fromApi(String? value) =>
      RequestStatusKind.values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => RequestStatusKind.open,
      );

  /// Transicoes aceitas pela API (mesma regra do servidor).
  List<RequestStatusKind> get nextOptions => switch (this) {
    RequestStatusKind.open => const [
      RequestStatusKind.inProgress,
      RequestStatusKind.waiting,
      RequestStatusKind.closed,
    ],
    RequestStatusKind.inProgress => const [
      RequestStatusKind.waiting,
      RequestStatusKind.resolved,
      RequestStatusKind.closed,
    ],
    RequestStatusKind.waiting => const [
      RequestStatusKind.inProgress,
      RequestStatusKind.resolved,
      RequestStatusKind.closed,
    ],
    RequestStatusKind.resolved => const [
      RequestStatusKind.closed,
      RequestStatusKind.inProgress,
    ],
    RequestStatusKind.closed => const [],
  };

  bool get isOpenLike => this == open || this == inProgress || this == waiting;
}

enum RequestPriorityKind {
  low('LOW', 'Baixa', AppColors.neutral),
  normal('NORMAL', 'Normal', AppColors.primary),
  high('HIGH', 'Alta', AppColors.accent),
  urgent('URGENT', 'Urgente', AppColors.alert);

  const RequestPriorityKind(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  static RequestPriorityKind fromApi(String? value) =>
      RequestPriorityKind.values.firstWhere(
        (p) => p.apiValue == value,
        orElse: () => RequestPriorityKind.normal,
      );
}

class RequestCategory {
  const RequestCategory({
    required this.id,
    required this.name,
    this.icon,
    this.slaHours,
  });

  factory RequestCategory.fromJson(Map<String, dynamic> json) =>
      RequestCategory(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String?,
        slaHours: (json['slaHours'] as num?)?.toInt(),
      );

  final String id;
  final String name;
  final String? icon;
  final int? slaHours;
}

class RequestSummary {
  const RequestSummary({
    required this.id,
    required this.number,
    required this.subject,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.confidentiality,
    this.categoryName,
    this.requesterName,
    this.assigneeName,
    this.pastoralName,
  });

  factory RequestSummary.fromJson(Map<String, dynamic> json) {
    String? person(Object? value) {
      final map = (value as Map?)?.cast<String, dynamic>();
      if (map == null) return null;
      return (map['pastoralName'] as String?) ??
          '${map['firstName'] ?? ''} ${map['lastName'] ?? ''}'.trim();
    }

    return RequestSummary(
      id: json['id'] as String,
      number: (json['number'] as num?)?.toInt() ?? 0,
      subject: json['subject'] as String? ?? '',
      status: RequestStatusKind.fromApi(json['status'] as String?),
      priority: RequestPriorityKind.fromApi(json['priority'] as String?),
      confidentiality: json['confidentiality'] as String? ?? 'NORMAL',
      createdAt: DateTime.parse(json['createdAt'] as String),
      categoryName:
          ((json['category'] as Map?)?.cast<String, dynamic>())?['name']
              as String?,
      requesterName: person(json['requester']),
      assigneeName: person(json['assignee']),
      pastoralName: person(json['pastor']),
    );
  }

  final String id;
  final int number;
  final String subject;
  final RequestStatusKind status;
  final RequestPriorityKind priority;
  final String confidentiality;
  final DateTime createdAt;
  final String? categoryName;
  final String? requesterName;
  final String? assigneeName;
  final String? pastoralName;
}

/// Entrada da linha do tempo (`kind`: SYSTEM, COMMENT, ASSIGNMENT, STATUS_CHANGE).
class RequestTimelineEntry {
  const RequestTimelineEntry({
    required this.id,
    required this.kind,
    required this.createdAt,
    required this.isInternal,
    this.message,
    this.authorName,
  });

  factory RequestTimelineEntry.fromJson(Map<String, dynamic> json) {
    final author = (json['author'] as Map?)?.cast<String, dynamic>();
    return RequestTimelineEntry(
      id: json['id'] as String,
      kind: json['kind'] as String? ?? 'SYSTEM',
      message: json['message'] as String?,
      isInternal: json['isInternal'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      authorName: author == null
          ? null
          : '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}'.trim(),
    );
  }

  final String id;
  final String kind;
  final String? message;
  final bool isInternal;
  final DateTime createdAt;
  final String? authorName;

  IconData get icon => switch (kind) {
    'COMMENT' => Icons.chat_bubble_outline_rounded,
    'ASSIGNMENT' => Icons.person_add_alt_1_outlined,
    'STATUS_CHANGE' => Icons.swap_horiz_rounded,
    _ => Icons.info_outline_rounded,
  };
}

class RequestDetail {
  const RequestDetail({
    required this.id,
    required this.number,
    required this.subject,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.timeline,
    this.categoryName,
    this.requesterName,
    this.requesterId,
    this.assigneeName,
    this.assigneeId,
    this.pastorId,
    this.pastoralName,
    this.resolution,
    this.resolvedAt,
  });

  factory RequestDetail.fromJson(Map<String, dynamic> json) {
    String? person(Object? value) {
      final map = (value as Map?)?.cast<String, dynamic>();
      if (map == null) return null;
      return (map['pastoralName'] as String?) ??
          '${map['firstName'] ?? ''} ${map['lastName'] ?? ''}'.trim();
    }

    return RequestDetail(
      id: json['id'] as String,
      number: (json['number'] as num?)?.toInt() ?? 0,
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: RequestStatusKind.fromApi(json['status'] as String?),
      priority: RequestPriorityKind.fromApi(json['priority'] as String?),
      createdAt: DateTime.parse(json['createdAt'] as String),
      categoryName:
          ((json['category'] as Map?)?.cast<String, dynamic>())?['name']
              as String?,
      requesterName: person(json['requester']),
      requesterId: json['requesterId'] as String?,
      assigneeName: person(json['assignee']),
      assigneeId: json['assigneeId'] as String?,
      pastorId: json['pastorId'] as String?,
      pastoralName: person(json['pastor']),
      resolution: json['resolution'] as String?,
      resolvedAt: json['resolvedAt'] is String
          ? DateTime.tryParse(json['resolvedAt'] as String)
          : null,
      timeline: [
        for (final entry
            in (json['timeline'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          RequestTimelineEntry.fromJson(entry),
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
    );
  }

  final String id;
  final int number;
  final String subject;
  final String description;
  final RequestStatusKind status;
  final RequestPriorityKind priority;
  final DateTime createdAt;
  final String? categoryName;
  final String? requesterName;
  final String? requesterId;
  final String? assigneeName;
  final String? assigneeId;
  final String? pastorId;
  final String? pastoralName;
  final String? resolution;
  final DateTime? resolvedAt;
  final List<RequestTimelineEntry> timeline;
}
