import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Acoes de contato sem custo de API: abrem o app do proprio dispositivo.
///
/// WhatsApp usa link `wa.me` (nao exige WhatsApp Business API).
/// Quando houver WhatsAppProvider no backend, estas acoes continuam como atalho.
abstract final class ContactActions {
  static Future<void> whatsApp(
    BuildContext context,
    String phoneE164, {
    String? message,
  }) => _open(
    context,
    Uri.https('wa.me', '/${phoneE164.replaceAll(RegExp(r'\D'), '')}', {
      'text': ?message,
    }),
    'Não foi possível abrir o WhatsApp.',
  );

  static Future<void> call(BuildContext context, String phoneE164) => _open(
    context,
    Uri(scheme: 'tel', path: phoneE164),
    'Não foi possível iniciar a ligação.',
  );

  static Future<void> email(BuildContext context, String email) => _open(
    context,
    Uri(scheme: 'mailto', path: email),
    'Não foi possível abrir o e-mail.',
  );

  static Future<void> openLink(BuildContext context, String url) =>
      _open(context, Uri.parse(url), 'Não foi possível abrir o link.');

  static Future<void> _open(
    BuildContext context,
    Uri uri,
    String failure,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) messenger?.showSnackBar(SnackBar(content: Text(failure)));
  }

  /// Formata E.164 para leitura (+55 31 98877-6655). Nao valida numero.
  static String formatPhone(String e164) {
    final digits = e164.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('55') && digits.length >= 12) {
      final ddd = digits.substring(2, 4);
      final rest = digits.substring(4);
      final split = rest.length - 4;
      return '+55 $ddd ${rest.substring(0, split)}-${rest.substring(split)}';
    }
    return e164;
  }
}
