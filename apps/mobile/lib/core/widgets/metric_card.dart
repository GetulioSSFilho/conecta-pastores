import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.valueColor = AppColors.primary,
    this.trend,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color valueColor;
  final String? trend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: color,
      padding: const EdgeInsets.all(AppTokens.space16),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: valueColor),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: AppTokens.space4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (trend != null)
            Text(
              trend!,
              style: TextStyle(
                color: valueColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
