import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Status ministerial do pastor (enum PastorStatus da API).
enum PastorStatus {
  active('ACTIVE', 'Ativo', AppColors.success),
  inTraining('IN_TRAINING', 'Em treinamento', AppColors.primary),
  onLeave('ON_LEAVE', 'Licença', AppColors.accent),
  suspended('SUSPENDED', 'Afastado', AppColors.accent),
  missionary('MISSIONARY', 'Missionário', AppColors.secondary),
  dismissed('DISMISSED', 'Desligado', AppColors.neutral),
  deceased('DECEASED', 'Falecido', AppColors.neutral);

  const PastorStatus(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  static PastorStatus fromApi(String? value) => PastorStatus.values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => PastorStatus.active,
  );
}
