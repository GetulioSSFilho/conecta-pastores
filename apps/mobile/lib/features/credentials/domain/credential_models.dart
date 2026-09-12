import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Tipo da credencial ministerial (CredentialType da API).
enum CredentialKind {
  ordination('ORDINATION', 'Credencial de ordenação'),
  ministerial('MINISTERIAL', 'Credencial ministerial'),
  missionary('MISSIONARY', 'Credencial missionária'),
  temporary('TEMPORARY', 'Credencial temporária'),
  other('OTHER', 'Credencial');

  const CredentialKind(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CredentialKind fromApi(String? value) =>
      CredentialKind.values.firstWhere(
        (k) => k.apiValue == value,
        orElse: () => CredentialKind.other,
      );
}

enum CredentialStatusKind {
  active('ACTIVE', 'Ativa', AppColors.success),
  pending('PENDING', 'Em emissão', AppColors.accent),
  expired('EXPIRED', 'Vencida', AppColors.alert),
  revoked('REVOKED', 'Revogada', AppColors.alert);

  const CredentialStatusKind(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  static CredentialStatusKind fromApi(String? value) =>
      CredentialStatusKind.values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => CredentialStatusKind.pending,
      );
}

/// Credencial pastoral (`GET /credentials`).
///
/// O QR Code aponta para a pagina publica de validacao usando um token opaco:
/// nenhum dado pessoal viaja dentro do codigo.
class PastoralCredential {
  const PastoralCredential({
    required this.id,
    required this.number,
    required this.kind,
    required this.status,
    required this.issuedAt,
    required this.verificationToken,
    this.expiresAt,
    this.pastoralName,
    this.pastorId,
  });

  factory PastoralCredential.fromJson(Map<String, dynamic> json) {
    final pastor = (json['pastor'] as Map?)?.cast<String, dynamic>();
    return PastoralCredential(
      id: json['id'] as String,
      number: json['number'] as String? ?? '',
      kind: CredentialKind.fromApi(json['type'] as String?),
      status: CredentialStatusKind.fromApi(json['status'] as String?),
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      verificationToken: json['verificationToken'] as String? ?? '',
      expiresAt: json['expiresAt'] is String
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      pastorId: json['pastorId'] as String?,
      pastoralName: pastor?['pastoralName'] as String?,
    );
  }

  final String id;
  final String number;
  final CredentialKind kind;
  final CredentialStatusKind status;
  final DateTime issuedAt;

  /// Token opaco da URL publica de validacao. Vazio quando o servidor nao envia.
  final String verificationToken;
  final DateTime? expiresAt;
  final String? pastorId;
  final String? pastoralName;

  bool get isActive => status == CredentialStatusKind.active;

  /// Fato, nao rotulo: data de validade tal como registrada.
  String get validityText {
    final date = expiresAt;
    if (date == null) return 'Sem data de validade';
    final month = '${date.month.toString().padLeft(2, '0')}/${date.year}';
    return date.isBefore(DateTime.now())
        ? 'Venceu em $month'
        : 'Válida até $month';
  }
}

/// Resposta publica de `GET /credentials/verify/:token`.
class CredentialVerification {
  const CredentialVerification({
    required this.valid,
    this.number,
    this.pastoralName,
    this.kind,
    this.issuedAt,
    this.expiresAt,
  });

  factory CredentialVerification.fromJson(Map<String, dynamic> json) =>
      CredentialVerification(
        valid: json['valid'] == true,
        number: json['number'] as String?,
        pastoralName: json['pastoralName'] as String?,
        kind: json['type'] == null
            ? null
            : CredentialKind.fromApi(json['type'] as String?),
        issuedAt: json['issuedAt'] is String
            ? DateTime.tryParse(json['issuedAt'] as String)
            : null,
        expiresAt: json['expiresAt'] is String
            ? DateTime.tryParse(json['expiresAt'] as String)
            : null,
      );

  final bool valid;
  final String? number;
  final String? pastoralName;
  final CredentialKind? kind;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
}
