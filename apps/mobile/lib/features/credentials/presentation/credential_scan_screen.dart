import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../data/credentials_providers.dart';

/// Validação de credencial pelo código do QR Code.
///
/// A leitura pela câmera acontece no app do celular; aqui o conferente digita
/// ou cola o código impresso/lido, e o resultado vem da API.
class CredentialScanScreen extends ConsumerStatefulWidget {
  const CredentialScanScreen({super.key});

  @override
  ConsumerState<CredentialScanScreen> createState() =>
      _CredentialScanScreenState();
}

class _CredentialScanScreenState extends ConsumerState<CredentialScanScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    final token = credentialTokenFrom(_controller.text);
    if (token == null) {
      setState(() => _error = 'Informe o código da credencial.');
      return;
    }
    setState(() => _error = null);
    context.go('/verify/$token');
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: EdgeInsets.all(padding),
          children: [
            Text(
              'Validar credencial',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Aponte a câmera para o QR Code e cole o endereço, ou digite o código da credencial.',
              style: TextStyle(color: AppColors.mutedInk),
            ),
            const SizedBox(height: AppTokens.space24),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _validate(),
                    decoration: InputDecoration(
                      labelText: 'Código ou link do QR Code',
                      prefixIcon: const Icon(Icons.qr_code_rounded),
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space16),
                  FilledButton.icon(
                    onPressed: _validate,
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Validar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.space16),
            const Text(
              'A conferência é pública: mostra apenas nome ministerial, número, tipo e validade.',
              style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
