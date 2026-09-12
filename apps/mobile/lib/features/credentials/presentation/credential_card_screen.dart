import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/contact_actions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_brand.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../data/credentials_providers.dart';
import '../domain/credential_models.dart';

/// Credencial digital do pastor, com QR Code de validação pública.
class CredentialCardScreen extends ConsumerWidget {
  const CredentialCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = context.windowSize.pagePadding;
    final user = ref.watch(currentUserProvider);
    final credentials = ref.watch(myCredentialsProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
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
              'Apresente o QR Code para validação. O código leva apenas a uma página pública de conferência.',
              style: TextStyle(color: AppColors.mutedInk),
            ),
            const SizedBox(height: AppTokens.space24),
            AsyncValueView(
              value: credentials,
              onRetry: () => ref.invalidate(myCredentialsProvider),
              loading: const SkeletonCard(lines: 5),
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

/// Cartão institucional: identidade, número, validade e QR de verificação.
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

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTokens.space24),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTokens.radius16),
              ),
            ),
            child: Column(
              children: [
                const AppBrandLockup(
                  color: Colors.white,
                  markSize: 30,
                  textStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
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
                    size: 84,
                  ),
                ),
                const SizedBox(height: AppTokens.space12),
                Text(
                  holderName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  credential.kind.label,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'Credencial',
                        value: credential.number,
                      ),
                    ),
                    Expanded(
                      child: _Field(
                        label: 'Emissão',
                        value: Formatters.date(credential.issuedAt),
                      ),
                    ),
                    Expanded(
                      child: _Field(
                        label: 'Validade',
                        value: credential.validityText,
                        color: credential.status.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: credential.status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    credential.status.label,
                    style: TextStyle(
                      color: credential.status.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (url != null) ...[
                  const SizedBox(height: AppTokens.space24),
                  QrImageView(
                    data: url,
                    size: 168,
                    backgroundColor: Colors.white,
                    // Tolera sujeira/reflexo na leitura do cartao impresso.
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                  const SizedBox(height: AppTokens.space8),
                  TextButton.icon(
                    onPressed: () => ContactActions.openLink(context, url),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Abrir página de validação'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.mutedInk, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.ink,
          ),
        ),
      ],
    );
  }
}
