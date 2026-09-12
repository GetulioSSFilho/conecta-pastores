import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/token_storage.dart';
import '../domain/auth_user.dart';

/// Acesso aos endpoints de autenticacao. Sem estado: quem guarda estado e o controller.
class AuthRepository {
  const AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  Future<AuthUser> login({
    required String email,
    required String password,
    required bool remember,
  }) async {
    final data =
        await _api.post(
              '/auth/login',
              publicEndpoint: true,
              body: {
                'email': email.trim(),
                'password': password,
                'platform': _platform(),
              },
            )
            as Map<String, dynamic>;

    final tokens = (data['tokens'] as Map).cast<String, dynamic>();
    final userJson = (data['user'] as Map).cast<String, dynamic>();

    await _storage.write(
      StoredSession(
        accessToken: tokens['accessToken'] as String,
        refreshToken: tokens['refreshToken'] as String,
        persistent: remember,
        userJson: userJson,
      ),
    );
    return AuthUser.fromJson(userJson);
  }

  /// Revalida a sessao salva com `/auth/me` (o interceptor renova o token se preciso).
  Future<AuthUser> me(AuthUser cached) async {
    final me = await _api.getJson('/auth/me');
    final user = cached.mergeMe(me);
    final session = await _storage.read();
    if (session != null) {
      await _storage.write(session.copyWith(userJson: user.toJson()));
    }
    return user;
  }

  Future<void> logout({bool allDevices = false}) async {
    try {
      await _api.post('/auth/logout', body: {'allDevices': allDevices});
    } finally {
      // Mesmo sem rede a sessao local e encerrada.
      await _storage.clear();
    }
  }

  /// Em DEV a API devolve `devToken` para permitir testar sem servico de e-mail.
  Future<String?> forgotPassword(String email) async {
    final data = await _api.post(
      '/auth/forgot-password',
      publicEndpoint: true,
      body: {'email': email.trim()},
    );
    return data is Map ? data['devToken'] as String? : null;
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) => _api.post(
    '/auth/reset-password',
    publicEndpoint: true,
    body: {'token': token, 'newPassword': newPassword},
  );

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _api.post(
    '/auth/change-password',
    body: {'currentPassword': currentPassword, 'newPassword': newPassword},
  );

  static String _platform() {
    if (kIsWeb) return 'WEB';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'IOS',
      _ => 'ANDROID',
    };
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  ),
);
