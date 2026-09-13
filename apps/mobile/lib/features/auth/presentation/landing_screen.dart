import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_brand.dart';

const loginHeroTag = 'conecta-login-cta';

/// Entrada publica da plataforma com uma animacao leve sobre a paisagem.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Semantics(
        label: 'Bem-vindo ao Conecta Pastores',
        child: Stack(
          fit: StackFit.expand,
          children: [
            _AnimatedMountain(animation: _animation),
            const _LandingOverlay(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 760;
                  final horizontalPadding = constraints.maxWidth < 360
                      ? 20.0
                      : 24.0;
                  final centerBottom = compact ? 164.0 : 180.0;

                  return Stack(
                    children: [
                      Positioned(
                        top: 20,
                        left: horizontalPadding,
                        right: horizontalPadding,
                        child: const AppBrandLockup(
                          label: 'Conecta Pastores',
                          markSize: 36,
                          color: Colors.white,
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: horizontalPadding,
                        right: horizontalPadding,
                        bottom: centerBottom,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppBrandMark(
                                size: compact ? 76 : 88,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Conecta\nPastores',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  height: .95,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.8,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Uma rede para cuidar de pessoas,\nigrejas e l\u00EDderes.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .86),
                                  fontSize: 15,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: horizontalPadding,
                        right: horizontalPadding,
                        bottom: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Mais que uma rede.\nUma miss\u00E3o.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: compact ? 12 : 20),
                            Align(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 460,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Hero(
                                    tag: loginHeroTag,
                                    child: FilledButton.icon(
                                      key: const Key('landing-login'),
                                      onPressed: () => context.go('/login'),
                                      icon: const Icon(Icons.login_rounded),
                                      label: const Text('Fazer login'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: AppColors.primary,
                                        padding: EdgeInsets.symmetric(
                                          vertical: compact ? 12 : 15,
                                        ),
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Acesso exclusivo para pastores e lideran\u00E7as',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .72),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedMountain extends StatelessWidget {
  const _AnimatedMountain({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final travel = math.max(22.0, constraints.maxWidth * .06);
        final verticalTravel = math.max(4.0, constraints.maxHeight * .01);

        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final progress = animation.value;
            final breathing = math.sin(progress * math.pi);
            return ClipRect(
              child: Transform.translate(
                offset: Offset(-travel * progress, -verticalTravel * breathing),
                child: Transform.scale(
                  scale: 1.10 + .05 * breathing,
                  child: const Image(
                    image: AssetImage('assets/images/mountain_sunrise.png'),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LandingOverlay extends StatelessWidget {
  const _LandingOverlay();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xA80A2F40), Color(0x3213303D), Color(0xD90A1E27)],
        stops: [.0, .48, 1],
      ),
    ),
  );
}
