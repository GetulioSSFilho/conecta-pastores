import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/token_storage.dart';
import '../config/app_config.dart';
import '../errors/app_failure.dart';

/// Cliente HTTP unico da aplicacao.
///
/// Responsabilidades:
///  - anexar o access token;
///  - renovar o token ao receber 401 (uma unica renovacao por vez);
///  - traduzir qualquer erro em [AppFailure] - telas nunca veem DioException.
///
/// O Flutter nunca decide autorizacao: um 403 aqui e a palavra final do servidor.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStorage storage,
    required void Function() onSessionExpired,
    Dio? dio,
  }) : _storage = storage,
       _onSessionExpired = onSessionExpired,
       _dio = dio ?? Dio(_options(baseUrl)),
       _plain = Dio(_options(baseUrl)) {
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: _attachToken,
        onError: _handleUnauthorized,
      ),
    );
  }

  static BaseOptions _options(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Accept': 'application/json'},
    responseType: ResponseType.json,
  );

  final TokenStorage _storage;
  final void Function() _onSessionExpired;
  final Dio _dio;

  /// Sem interceptors: usado para refresh e para repetir a requisicao original,
  /// evitando deadlock na fila do QueuedInterceptorsWrapper.
  final Dio _plain;

  static const _skipAuthRefresh = 'skipAuthRefresh';

  // ---------------------------------------------------------------------------
  // API publica
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async => _asMap(
    await _send(() => _dio.get<Object?>(path, queryParameters: _clean(query))),
  );

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final data = await _send(
      () => _dio.get<Object?>(path, queryParameters: _clean(query)),
    );
    return data is List ? data : const [];
  }

  Future<Object?> post(
    String path, {
    Object? body,
    bool publicEndpoint = false,
  }) => _send(
    () => _dio.post<Object?>(path, data: body, options: _opts(publicEndpoint)),
  );

  Future<Object?> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<Object?>(path, data: body));

  Future<Object?> put(String path, {Object? body}) =>
      _send(() => _dio.put<Object?>(path, data: body));

  Future<Object?> delete(String path) =>
      _send(() => _dio.delete<Object?>(path));

  Future<Object?> upload(String path, FormData form) =>
      _send(() => _dio.post<Object?>(path, data: form));

  // ---------------------------------------------------------------------------
  // Internos
  // ---------------------------------------------------------------------------

  Options? _opts(bool publicEndpoint) =>
      publicEndpoint ? Options(extra: {_skipAuthRefresh: true}) : null;

  Future<Object?> _send(Future<Response<Object?>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (error) {
      throw _toFailure(error);
    }
  }

  Future<void> _attachToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[_skipAuthRefresh] != true) {
      final session = await _storage.read();
      if (session != null) {
        options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
    }
    handler.next(options);
  }

  Future<void> _handleUnauthorized(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final isUnauthorized = error.response?.statusCode == 401;
    if (!isUnauthorized || request.extra[_skipAuthRefresh] == true) {
      return handler.next(error);
    }

    final session = await _storage.read();
    if (session == null) {
      _onSessionExpired();
      return handler.next(error);
    }

    // Outra requisicao da fila ja renovou o token: apenas repete com o novo.
    final sentWith = request.headers['Authorization'];
    if (sentWith != null && sentWith != 'Bearer ${session.accessToken}') {
      return _retry(request, session.accessToken, handler, error);
    }

    try {
      final response = await _plain.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': session.refreshToken},
      );
      final data = response.data!;
      final renewed = session.copyWith(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      await _storage.write(renewed);
      return _retry(request, renewed.accessToken, handler, error);
    } on DioException catch (refreshError) {
      // Refresh recusado (expirado/revogado/reuso): sessao encerrada de fato.
      // Falha de rede no refresh NAO desloga - o usuario pode tentar de novo.
      if (refreshError.response?.statusCode == 401 ||
          refreshError.response?.statusCode == 403) {
        await _storage.clear();
        _onSessionExpired();
      }
      return handler.next(error);
    }
  }

  Future<void> _retry(
    RequestOptions request,
    String accessToken,
    ErrorInterceptorHandler handler,
    DioException original,
  ) async {
    try {
      request.headers['Authorization'] = 'Bearer $accessToken';
      final response = await _plain.fetch<Object?>(request);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (_) {
      handler.next(original);
    }
  }

  static AppFailure _toFailure(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return const AppFailure(kind: FailureKind.network);
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        final body = error.response?.data;
        final map = body is Map
            ? body.cast<String, dynamic>()
            : const <String, dynamic>{};
        return AppFailure(
          kind: AppFailure.kindForStatus(status),
          statusCode: status,
          code: map['code'] as String?,
          message: map['message'] as String?,
          details: map['details'],
          requestId:
              map['requestId'] as String? ??
              error.response?.headers.value('x-request-id'),
        );
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        // No web, CORS bloqueado e servidor desligado chegam como `unknown` sem resposta.
        return error.response == null
            ? const AppFailure(kind: FailureKind.network)
            : const AppFailure(kind: FailureKind.unknown);
    }
  }

  static Map<String, dynamic> _asMap(Object? data) =>
      data is Map ? data.cast<String, dynamic>() : const <String, dynamic>{};

  /// Remove filtros vazios: a API valida query com whitelist estrita.
  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    return {
      for (final entry in query.entries)
        if (entry.value != null &&
            !(entry.value is String && (entry.value as String).isEmpty))
          entry.key: entry.value is DateTime
              ? (entry.value as DateTime).toUtc().toIso8601String()
              : entry.value,
    };
  }
}

/// `onSessionExpired` e resolvido de forma tardia para evitar dependencia circular
/// entre o cliente HTTP e o controlador de autenticacao.
final sessionExpiredHandlerProvider = Provider<void Function()>((ref) => () {});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
    storage: ref.watch(tokenStorageProvider),
    onSessionExpired: () => ref.read(sessionExpiredHandlerProvider)(),
  );
});
