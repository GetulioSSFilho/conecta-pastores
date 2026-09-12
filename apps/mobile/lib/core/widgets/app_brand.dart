import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

class AppBrandMark extends StatelessWidget {
  const AppBrandMark({
    super.key,
    this.size = 44,
    this.color = AppColors.primary,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: SvgPicture.asset(
      'assets/Logo.svg',
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: 'Logo Conecta Pastores',
    ),
  );
}

class AppBrandLockup extends StatelessWidget {
  const AppBrandLockup({
    super.key,
    this.label = 'Conecta\nPastores',
    this.color = AppColors.primary,
    this.markSize = 44,
    this.textStyle,
  });

  final String label;
  final Color color;
  final double markSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppBrandMark(size: markSize, color: color),
      const SizedBox(width: 10),
      Text(
        label,
        style:
            textStyle ??
            TextStyle(
              color: color,
              fontSize: markSize * 0.38,
              height: 1.0,
              fontWeight: FontWeight.w800,
            ),
      ),
    ],
  );
}
