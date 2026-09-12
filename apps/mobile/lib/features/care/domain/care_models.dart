import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Nivel de confidencialidade do registro (Confidentiality da API).
///
/// Quem pode ler o quê é decidido pelo servidor; aqui apenas rotulamos.
enum CareConfidentiality {
  normal('NORMAL', 'Normal', AppColors.mutedInk),
  restricted('RESTRICTED', 'Restrito', AppColors.accent),
  confidential('CONFIDENTIAL', 'Confidencial', AppColors.alert);

  const CareConfidentiality(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  static CareConfidentiality fromApi(String? value) =>
      CareConfidentiality.values.firstWhere(
        (c) => c.apiValue == value,
        orElse: () => CareConfidentiality.normal,
      );

  String get description => switch (this) {
    CareConfidentiality.normal => 'Visível para quem acompanha este pastor.',
    CareConfidentiality.restricted =>
      'Visível apenas para a cadeia de liderança direta.',
    CareConfidentiality.confidential =>
      'Visível apenas para você e para quem tem acesso confidencial.',
  };
}

enum CareStatusKind {
  planned('PLANNED', 'Planejado'),
  done('DONE', 'Realizado'),
  canceled('CANCELED', 'Cancelado'),
  noShow('NO_SHOW', 'Não compareceu');

  const CareStatusKind(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CareStatusKind fromApi(String? value) =>
      CareStatusKind.values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => CareStatusKind.done,
      );
}

/// Tipo configuravel de acompanhamento (`GET /care/types`).
class CareType {
  const CareType({
    required this.id,
    required this.key,
    required this.name,
    this.colorHex,
    this.iconName,
  });

  factory CareType.fromJson(Map<String, dynamic> json) => CareType(
    id: json['id'] as String,
    key: json['key'] as String? ?? '',
    name: json['name'] as String? ?? '',
    colorHex: json['color'] as String?,
    iconName: json['icon'] as String?,
  );

  final String id;
  final String key;
  final String name;
  final String? colorHex;
  final String? iconName;

  Color get color {
    final hex = colorHex;
    if (hex == null || hex.length != 7) return AppColors.primary;
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }

  IconData get icon => switch (iconName) {
    'forum' => Icons.forum_outlined,
    'call' => Icons.call_outlined,
    'groups' => Icons.groups_2_outlined,
    'home' => Icons.home_outlined,
    'church' => Icons.church_outlined,
    'assignment' => Icons.assignment_outlined,
    _ => Icons.volunteer_activism_outlined,
  };
}

/// Registro de cuidado pastoral (`GET /care`, `GET /care/:id`).
class CareRecord {
  const CareRecord({
    required this.id,
    required this.occurredAt,
    required this.status,
    required this.summary,
    required this.confidentiality,
    required this.typeName,
    required this.typeColor,
    required this.pastorId,
    required this.pastoralName,
    this.pastorPhotoUrl,
    this.performedByName,
    this.nextAction,
    this.nextCareAt,
    this.notes,
    this.location,
    this.durationMinutes,
  });

  factory CareRecord.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pastor =
        (json['pastor'] as Map?)?.cast<String, dynamic>() ?? const {};
    final performedBy = (json['performedBy'] as Map?)?.cast<String, dynamic>();
    final hex = type['color'] as String?;
    return CareRecord(
      id: json['id'] as String,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      status: CareStatusKind.fromApi(json['status'] as String?),
      summary: json['summary'] as String? ?? '',
      confidentiality: CareConfidentiality.fromApi(
        json['confidentiality'] as String?,
      ),
      typeName: type['name'] as String? ?? 'Acompanhamento',
      typeColor: hex != null && hex.length == 7
          ? Color(int.parse('FF${hex.substring(1)}', radix: 16))
          : AppColors.primary,
      pastorId: pastor['id'] as String? ?? '',
      pastoralName: pastor['pastoralName'] as String? ?? '',
      pastorPhotoUrl: pastor['photoUrl'] as String?,
      performedByName: performedBy == null
          ? null
          : '${performedBy['firstName'] ?? ''} ${performedBy['lastName'] ?? ''}'
                .trim(),
      nextAction: json['nextAction'] as String?,
      nextCareAt: json['nextCareAt'] is String
          ? DateTime.tryParse(json['nextCareAt'] as String)
          : null,
      notes: json['notes'] as String?,
      location: json['location'] as String?,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
    );
  }

  final String id;
  final DateTime occurredAt;
  final CareStatusKind status;
  final String summary;
  final CareConfidentiality confidentiality;
  final String typeName;
  final Color typeColor;
  final String pastorId;
  final String pastoralName;
  final String? pastorPhotoUrl;
  final String? performedByName;
  final String? nextAction;
  final DateTime? nextCareAt;
  final String? notes;
  final String? location;
  final int? durationMinutes;
}

/// Dados para registrar um acompanhamento (`POST /care`).
class NewCare {
  const NewCare({
    required this.pastorId,
    required this.typeId,
    required this.occurredAt,
    required this.summary,
    this.notes,
    this.nextAction,
    this.nextCareAt,
    this.confidentiality = CareConfidentiality.normal,
    this.durationMinutes,
    this.location,
  });

  final String pastorId;
  final String typeId;
  final DateTime occurredAt;
  final String summary;
  final String? notes;
  final String? nextAction;
  final DateTime? nextCareAt;
  final CareConfidentiality confidentiality;
  final int? durationMinutes;
  final String? location;

  Map<String, dynamic> toApi() => {
    'pastorId': pastorId,
    'typeId': typeId,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'summary': summary.trim(),
    if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    if (nextAction != null && nextAction!.trim().isNotEmpty)
      'nextAction': nextAction!.trim(),
    if (nextCareAt != null) 'nextCareAt': nextCareAt!.toUtc().toIso8601String(),
    'confidentiality': confidentiality.apiValue,
    if (durationMinutes != null) 'durationMinutes': durationMinutes,
    if (location != null && location!.trim().isNotEmpty)
      'location': location!.trim(),
  };
}
