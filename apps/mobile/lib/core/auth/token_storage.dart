import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_marker.dart';

/// Tokens persistidos localmente.
class StoredSession {
  const StoredSession({
    required this.accessToken,
    required this.refreshToken,
    required this.persistent,
    this.userJson,
  });

  final String accessToken;
  final String refreshToken;

  /// true = "Lembrar de mim": sobrevive a fechar o navegador/app.
  final bool persistent;

  /// Ultimo usuario carregado: permite abrir o app sem rede com dados recentes.
  final Map<String, dynamic>? userJson;

  StoredSession copyWith({
    String? accessToken,
    String? refreshToken,
    Map<String, dynamic>? userJson,
  }) => StoredSession(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    persistent: persistent,
    userJson: userJson ?? this.userJson,
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'persistent': persistent,
    'user': userJson,
  };

  static StoredSession? fromJson(Map<String, dynamic> json) {
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    if (access is! String || refresh is! String) return null;
    return StoredSession(
      accessToken: access,
      refreshToken: refresh,
      persistent: json['persistent'] == true,
      userJson: (json['user'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

/// Armazena a sessao com flutter_secure_storage
/// (Keychain no iOS, Keystore no Android, WebCrypto + localStorage no web).
///
/// Sessao sem "Lembrar de mim": os tokens ficam gravados, mas so valem enquanto
/// existir o marcador de sessao (sessionStorage no web, memoria no mobile).
/// Assim F5 no navegador NAO desloga, mas fechar a aba/app sim.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage, SessionMarker? marker})
    : _storage = storage ?? const FlutterSecureStorage(),
      _marker = marker ?? createSessionMarker();

  static const _key = 'pastoral.session.v1';

  final FlutterSecureStorage _storage;
  final SessionMarker _marker;
  StoredSession? _cache;

  Future<StoredSession?> read() async {
    if (_cache != null) return _cache;
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;

    final session = StoredSession.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    if (session == null) {
      await clear();
      return null;
    }
    if (!session.persistent && !_marker.isActive) {
      await clear();
      return null;
    }
    return _cache = session;
  }

  Future<void> write(StoredSession session) async {
    _cache = session;
    if (!session.persistent) _marker.activate();
    await _storage.write(key: _key, value: jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    _cache = null;
    _marker.clear();
    await _storage.delete(key: _key);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
