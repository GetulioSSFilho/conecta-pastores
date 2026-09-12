import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/contact_actions.dart';
import '../../../core/widgets/app_brand.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../data/credentials_providers.dart';
import '../domain/credential_models.dart';

/// Credencial digital do pastor, no formato do cartão institucional:
/// cartão escuro, identidade, número e validade, QR de conferência.
class CredentialCardScreen extends ConsumerWidget {
  const CredentialCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = context.windowSize.pagePadding;
    final user = ref.watch(currentUserProvider);
    final credentials = ref.watch(myCredentialsProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            padding,
            padding,
            padding,
            AppTokens.space32,
          ),
          children: [
            Text(
              'Credencial digital',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Apresente o QR Code para conferência. O código leva apenas a uma '
              'página pública de validação.',
              style: TextStyle(color: AppColors.mutedInk),
            ),
            const SizedBox(height: AppTokens.space24),
            AsyncValueView(
              value: credentials,
              onRetry: () => ref.invalidate(myCredentialsProvider),
              loading: const SkeletonCard(lines: 6),
              data: (list) => list.isEmpty
                  ? const InlineEmpty(
                      icon: Icons.badge_outlined,
                      message: 'Nenhuma credencial emitida para você.',
                    )
                  : Column(
                      children: [
                        for (final credential in list)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppTokens.space16,
                            ),
                            child: CredentialCard(
                              credential: credential,
                              holderName:
                                  credential.pastoralName ??
                                  user?.displayName ??
                                  '',
                              photoUrl: user?.avatarUrl,
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: AppTokens.space8),
            OutlinedButton.icon(
              onPressed: () => context.go('/credential/scan'),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Validar uma credencial'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartão da credencial: fundo institucional, QR e situação real.
class CredentialCard extends ConsumerWidget {
  const CredentialCard({
    super.key,
    required this.credential,
    required this.holderName,
    this.photoUrl,
  });

  final PastoralCredential credential;
  final String holderName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final token = credential.verificationToken;
    final url = token.isEmpty
        ? null
        : credentialVerifyUrl(ref.watch(appConfigProvider), token);
    final validade = credential.expiresAt;
    final validadeText = validade == null
        ? 'Sem validade'
        : 'Val. ${validade.month.toString().padLeft(2, '0')}/${validade.year}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppTokens.radius24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F4C5C),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: AppBrandLockup(
                    color: Colors.white,
                    markSize: 26,
                    textStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (url != null)
                  IconButton(
                    tooltip: 'Abrir página de validação',
                    onPressed: () => ContactActions.openLink(context, url),
                    icon: const Icon(Icons.ios_share_rounded, size: 20),
                    color: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.space16),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: PersonAvatar(
                name: holderName,
                photoUrl: photoUrl,
                size: 96,
              ),
            ),
            const SizedBox(height: AppTokens.space16),
            Text(
              holderName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              credential.kind.label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11.5,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTokens.space16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Nº ${credential.number}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Container(
                  width: 1,
                  height: 14,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space12,
                  ),
                  color: Colors.white24,
                ),
                Text(
                  validadeText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (url != null) ...[
              const SizedBox(height: AppTokens.space24),
              Container(
                padding: const EdgeInsets.all(AppTokens.space12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTokens.radius16),
                ),
                child: QrImageView(
                  data: url,
                  size: 168,
                  backgroundColor: Colors.white,
                  // Tolera reflexo e sujeira na leitura do cartão impresso.
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
            ],
            const SizedBox(height: AppTokens.space20),
            _StatusPill(credential: credential),
          ],
        ),
      ),
    );
  }
}

/// Situação da credencial como fato: quem confere precisa saber se vale hoje.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.credential});

  final PastoralCredential credential;

  @override
  Widget build(BuildContext context) {
    final ativa = credential.isActive;
    final vencida =
        credential.expiresAt != null &&
        credential.expiresAt!.isBefore(DateTime.now());
    final (texto, icone, cor) = switch ((ativa, vencida)) {
      (true, false) => (
        'Credencial válida',
        Icons.check_circle_rounded,
        AppColors.success,
      ),
      (true, true) => (
        credential.validityText,
        Icons.error_outline_rounded,
        AppColors.accent,
      ),
      _ => (
        credential.status.label,
        Icons.info_outline_rounded,
        AppColors.accent,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}
