import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paginated.dart';
import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/credential_models.dart';

/// Credenciais de um pastor (a API aplica o escopo de quem consulta).
final pastorCredentialsProvider = FutureProvider.autoDispose
    .family<List<PastoralCredential>, String>((ref, pastorId) async {
      final json = await ref
          .watch(apiClientProvider)
          .getJson(
            '/credentials',
            query: {'pastorId': pastorId, 'pageSize': 20},
          );
      return Paginated.fromJson(
        json,
        PastoralCredential.fromJson,
      ).items.toList()..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    });

/// Credenciais do usuario autenticado (vazio quando ele nao e pastor).
final myCredentialsProvider =
    FutureProvider.autoDispose<List<PastoralCredential>>((ref) async {
      final pastorId = ref.watch(currentUserProvider)?.pastorId;
      if (pastorId == null) return const [];
      return ref.watch(pastorCredentialsProvider(pastorId).future);
    });

/// URL embutida no QR Code: pagina publica de validacao com token opaco.
/// Nenhum dado pessoal viaja no codigo.
String credentialVerifyUrl(AppConfig config, String token) =>
    '${config.webPublicUrl}/verify/$token';

/// Extrai o token de um codigo digitado ou de uma URL colada.
String? credentialTokenFrom(String input) {
  final value = input.trim();
  if (value.isEmpty) return null;
  final marker = value.lastIndexOf('/verify/');
  final token = marker >= 0
      ? value.substring(marker + '/verify/'.length)
      : value;
  final clean = token.split(RegExp(r'[?#/]')).first.trim();
  return clean.isEmpty ? null : clean;
}

/// Consulta publica de validacao (nao exige sessao).
final verifyCredentialProvider = FutureProvider.autoDispose
    .family<CredentialVerification, String>((ref, token) async {
      final json = await ref
          .watch(apiClientProvider)
          .getJson('/credentials/verify/$token');
      return CredentialVerification.fromJson(json);
    });
