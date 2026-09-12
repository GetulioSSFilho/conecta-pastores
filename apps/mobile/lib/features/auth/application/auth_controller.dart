import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/errors/app_failure.dart';
import '../data/auth_repository.dart';
import '../domain/auth_user.dart';

/// Estado de autenticacao consumido pelo roteador e pelo shell.
sealed class AuthState {
  const AuthState();
}

/// Restaurando sessao salva (splash).
class AuthRestoring extends AuthState {
  const AuthRestoring();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.reason});

  /// Preenchido quando a sessao foi encerrada pelo servidor (expirada/revogada).
  final String? reason;
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user, {this.offline = false});

  final AuthUser user;

  /// Aberto com usuario em cache porque a API estava inacessivel.
  final bool offline;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    unawaited(Future.microtask(_restore));
    return const AuthRestoring();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  AuthUser? get currentUser => switch (state) {
    AuthSignedIn(:final user) => user,
    _ => null,
  };

  Future<void> _restore() async {
    final session = await ref.read(tokenStorageProvider).read();
    final cachedJson = session?.userJson;
    if (session == null || cachedJson == null) {
      state = const AuthSignedOut();
      return;
    }

    final cached = AuthUser.fromJson(cachedJson);
    try {
      state = AuthSignedIn(await _repo.me(cached));
    } on AppFailure catch (failure) {
      state = switch (failure.kind) {
        // Falhas temporarias (sem rede, servidor instavel, limite de requisicoes)
        // NAO encerram a sessao: abre com os dados recentes em modo offline.
        FailureKind.network ||
        FailureKind.server ||
        FailureKind.rateLimited => AuthSignedIn(cached, offline: true),
        _ => const AuthSignedOut(),
      };
      if (state is AuthSignedOut) await ref.read(tokenStorageProvider).clear();
    }
  }

  Future<void> login({
    required String email,
    required String password,
    required bool remember,
  }) async {
    final user = await _repo.login(
      email: email,
      password: password,
      remember: remember,
    );
    state = AuthSignedIn(user);
  }

  Future<void> logout({bool allDevices = false}) async {
    try {
      await _repo.logout(allDevices: allDevices);
    } on AppFailure {
      // Sessao local ja foi limpa pelo repositorio.
    }
    state = const AuthSignedOut();
  }

  /// Chamado pelo ApiClient quando o servidor recusa renovar a sessao.
  void handleSessionExpired() {
    if (state is AuthSignedIn) state = const AuthSignedOut(reason: 'expired');
  }

  Future<void> retryRestore() async {
    state = const AuthRestoring();
    await _restore();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Liga o aviso de "sessao expirada" do ApiClient ao controlador.
/// Aplicado no ProviderScope raiz: `core/` nao conhece `features/`.
final authSessionExpiredOverride = sessionExpiredHandlerProvider.overrideWith(
  (ref) =>
      () => ref.read(authControllerProvider.notifier).handleSessionExpired(),
);

/// Atalho para o usuario atual (null quando deslogado).
final currentUserProvider = Provider<AuthUser?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthSignedIn ? state.user : null;
});
