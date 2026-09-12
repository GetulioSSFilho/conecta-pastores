import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Bloco "esqueleto" pulsante para estados de carregamento.
///
/// Preferido a spinner: mantem o layout estavel e comunica o formato do conteudo.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppTokens.radius8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respeita "reduzir movimento" do sistema.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );
    if (reduceMotion) return box;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_controller),
      child: box,
    );
  }
}

/// Card generico de carregamento com linhas.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = 3, this.height});

  final int lines;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando',
      child: Container(
        height: height,
        padding: const EdgeInsets.all(AppTokens.space16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Skeleton(width: 140, height: 16),
            for (var i = 0; i < lines; i++) ...[
              const SizedBox(height: AppTokens.space12),
              Row(
                children: [
                  const Skeleton(width: 36, height: 36, radius: 18),
                  const SizedBox(width: AppTokens.space12),
                  Expanded(
                    child: Skeleton(height: 12, width: i.isEven ? null : 160),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
