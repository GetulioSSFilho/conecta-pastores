import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_brand.dart';

/// Entrada pública da plataforma. A animação é nativa e leve: um movimento
/// lento de câmera sobre a paisagem cria o efeito de vídeo sem baixar um
/// arquivo pesado para cada visita.
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space24,
                  AppTokens.space20,
                  AppTokens.space24,
                  AppTokens.space24,
                ),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: AppBrandLockup(
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
                    const Spacer(),
                    const AppBrandMark(size: 88, color: Colors.white),
                    const SizedBox(height: AppTokens.space16),
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
                    const SizedBox(height: AppTokens.space16),
                    Text(
                      'Uma rede para cuidar de pessoas,\nigrejas e líderes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .86),
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    const Spacer(flex: 2),
                    const Text(
                      'Mais que uma rede.\nUma missão.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('landing-login'),
                        onPressed: () => context.go('/login'),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Fazer login'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space12),
                    Text(
                      'Acesso exclusivo para pastores e lideranças',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .72),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
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
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = animation.value;
        return ClipRect(
          child: Transform.translate(
            offset: Offset(-10 * progress, 0),
            child: Transform.scale(
              scale: 1.06 + .035 * math.sin(progress * math.pi),
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
