import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Categoria do documento (DocumentCategory da API).
enum DocumentCategory {
  pastoral(
    'PASTORAL_DOCUMENT',
    'Documento pastoral',
    Icons.description_outlined,
  ),
  certificate('CERTIFICATE', 'Certificado', Icons.workspace_premium_outlined),
  ministerial(
    'MINISTERIAL_DOCUMENT',
    'Documento ministerial',
    Icons.church_outlined,
  ),
  authorization('AUTHORIZATION', 'Autorização', Icons.verified_user_outlined),
  identification('IDENTIFICATION', 'Identificação', Icons.badge_outlined),
  other('OTHER', 'Outro', Icons.folder_outlined);

  const DocumentCategory(this.apiValue, this.label, this.icon);

  final String apiValue;
  final String label;
  final IconData icon;

  static DocumentCategory fromApi(String? value) =>
      DocumentCategory.values.firstWhere(
        (c) => c.apiValue == value,
        orElse: () => DocumentCategory.other,
      );
}

/// Situacao de validade, em fatos (dias), sem julgamento.
enum DocumentValidity {
  expired('Vencido', AppColors.alert),
  expiringSoon('Vence em breve', AppColors.accent),
  valid('Em dia', AppColors.success),
  noExpiry('Sem validade', AppColors.mutedInk);

  const DocumentValidity(this.label, this.color);

  final String label;
  final Color color;
}

class PastoralDocument {
  const PastoralDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.confidentiality,
    required this.mimeType,
    required this.sizeBytes,
    this.description,
    this.issuedAt,
    this.expiresAt,
    this.pastorId,
    this.pastoralName,
  });

  factory PastoralDocument.fromJson(Map<String, dynamic> json) {
    final pastor = (json['pastor'] as Map?)?.cast<String, dynamic>();
    return PastoralDocument(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      category: DocumentCategory.fromApi(json['category'] as String?),
      confidentiality: json['confidentiality'] as String? ?? 'NORMAL',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      // BigInt no banco chega como numero ou string.
      sizeBytes: json['sizeBytes'] is num
          ? (json['sizeBytes'] as num).toInt()
          : int.tryParse('${json['sizeBytes']}') ?? 0,
      issuedAt: json['issuedAt'] is String
          ? DateTime.tryParse(json['issuedAt'] as String)
          : null,
      expiresAt: json['expiresAt'] is String
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      pastorId: json['pastorId'] as String?,
      pastoralName: pastor?['pastoralName'] as String?,
    );
  }

  final String id;
  final String title;
  final String? description;
  final DocumentCategory category;
  final String confidentiality;
  final String mimeType;
  final int sizeBytes;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final String? pastorId;
  final String? pastoralName;

  int? get daysUntilExpiry {
    final date = expiresAt;
    if (date == null) return null;
    return date.difference(DateTime.now()).inDays;
  }

  DocumentValidity get validity {
    final days = daysUntilExpiry;
    if (days == null) return DocumentValidity.noExpiry;
    if (days < 0) return DocumentValidity.expired;
    if (days <= 60) return DocumentValidity.expiringSoon;
    return DocumentValidity.valid;
  }

  /// Texto factual de validade: "Vencido há 12 dias", "Vence em 30 dias".
  String get validityText {
    final days = daysUntilExpiry;
    if (days == null) return 'Sem data de validade';
    if (days < 0) return 'Vencido há ${-days} ${days == -1 ? 'dia' : 'dias'}';
    if (days == 0) return 'Vence hoje';
    return 'Vence em $days ${days == 1 ? 'dia' : 'dias'}';
  }

  String get sizeText {
    if (sizeBytes >= 1048576) {
      return '${(sizeBytes / 1048576).toStringAsFixed(1)} MB';
    }
    if (sizeBytes >= 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '$sizeBytes B';
  }

  IconData get fileIcon => switch (mimeType) {
    'application/pdf' => Icons.picture_as_pdf_outlined,
    final m when m.startsWith('image/') => Icons.image_outlined,
    final m when m.contains('sheet') || m.contains('excel') =>
      Icons.table_chart_outlined,
    final m when m.contains('word') => Icons.article_outlined,
    _ => Icons.insert_drive_file_outlined,
  };
}
