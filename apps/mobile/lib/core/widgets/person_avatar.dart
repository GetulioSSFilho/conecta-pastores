import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Avatar com foto remota e fallback para iniciais (sem quebrar quando a URL falha).
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 40,
    this.color = AppColors.primary,
  });

  final String name;
  final String? photoUrl;
  final double size;
  final Color color;

  static String initialsOf(String name) {
    final parts = name
        .replaceAll(RegExp(r'^(Pr|Pra|Bp|Rev)\.\s*', caseSensitive: false), '')
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final isAsset =
        url != null &&
        (url.startsWith('assets/') || url.startsWith('/assets/'));
    return Semantics(
      image: true,
      label: name,
      excludeSemantics: true,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundImage: url != null && url.isNotEmpty
            ? isAsset
                  ? AssetImage(url)
                  : NetworkImage(url)
            : null,
        onForegroundImageError: url != null && url.isNotEmpty
            ? (_, _) {}
            : null,
        child: Text(
          initialsOf(name),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.34,
          ),
        ),
      ),
    );
  }
}
