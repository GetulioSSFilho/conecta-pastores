import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_brand.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/credentials_providers.dart';
import '../domain/credential_models.dart';

/// Pagina publica de validacao de credencial (`/verify/:token`).
///
/// Acessivel sem sessao: e o destino do QR Code. Mostra somente o que a API
/// decide expor publicamente - nome ministerial, numero, tipo e validade.
class CredentialVerifyScreen extends ConsumerWidget {
  const CredentialVerifyScreen({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(verifyCredentialProvider(token));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.space24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppBrandLockup(markSize: 44),
                const SizedBox(height: AppTokens.space24),
                AppCard(
                  child: AsyncValueView(
                    value: result,
                    onRetry: () =>
                        ref.invalidate(verifyCredentialProvider(token)),
                    loading: const SkeletonCard(lines: 4),
                    data: (verification) => verification.valid
                        ? _Valid(verification: verification)
                        : const _Invalid(),
                  ),
                ),
                const SizedBox(height: AppTokens.space16),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Entrar na plataforma'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Valid extends StatelessWidget {
  const _Valid({required this.verification});

  final CredentialVerification verification;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.verified_rounded, color: AppColors.success, size: 48),
        const SizedBox(height: AppTokens.space12),
        const Text(
          'Credencial ativa',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: AppTokens.space16),
        _Line(
          label: 'Nome ministerial',
          value: verification.pastoralName ?? '—',
        ),
        _Line(label: 'Número', value: verification.number ?? '—'),
        _Line(label: 'Tipo', value: verification.kind?.label ?? '—'),
        _Line(
          label: 'Emissão',
          value: verification.issuedAt == null
              ? '—'
              : Formatters.date(verification.issuedAt!),
        ),
        _Line(
          label: 'Validade',
          value: verification.expiresAt == null
              ? 'Sem data de validade'
              : Formatters.date(verification.expiresAt!),
        ),
        const SizedBox(height: AppTokens.space16),
        Text(
          'Conferido em ${Formatters.date(DateTime.now())}',
          style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
        ),
      ],
    );
  }
}

class _Invalid extends StatelessWidget {
  const _Invalid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.gpp_bad_outlined, color: AppColors.alert, size: 48),
        SizedBox(height: AppTokens.space12),
        Text(
          'Credencial não confirmada',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.alert,
          ),
        ),
        SizedBox(height: AppTokens.space8),
        Text(
          'Este código não corresponde a uma credencial ativa e dentro da validade.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.mutedInk),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedInk),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
