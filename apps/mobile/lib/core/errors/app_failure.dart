/// Categoria da falha, independente do texto enviado pelo servidor.
///
/// A UI decide mensagem e acao (retry, login, voltar) pela categoria e pelo
/// `code` estavel da API - nunca pelo texto, que pode mudar ou vir em outro idioma.
enum FailureKind {
  /// 400 - dados invalidos.
  validation,

  /// 401 - sessao ausente, expirada ou revogada.
  unauthorized,

  /// 403 - sem permissao ou fora do escopo.
  forbidden,

  /// 404.
  notFound,

  /// 409 - conflito de estado (duplicidade, vinculos).
  conflict,

  /// 422 - regra de negocio (ex.: ciclo na hierarquia).
  unprocessable,

  /// 429 - limite de requisicoes.
  rateLimited,

  /// 5xx.
  server,

  /// Sem conexao, timeout ou servidor inacessivel.
  network,

  unknown,
}

class AppFailure implements Exception {
  const AppFailure({
    required this.kind,
    this.statusCode,
    this.code,
    this.message,
    this.details,
    this.requestId,
  });

  final FailureKind kind;
  final int? statusCode;

  /// Codigo estavel da API (ex.: `OUT_OF_SCOPE`, `INVALID_CREDENTIALS`).
  final String? code;

  /// Mensagem do servidor. Usar apenas como detalhe, nunca como texto principal.
  final String? message;
  final Object? details;

  /// Correlation id para suporte ("informe este codigo").
  final String? requestId;

  static FailureKind kindForStatus(int? status) => switch (status) {
    400 => FailureKind.validation,
    401 => FailureKind.unauthorized,
    403 => FailureKind.forbidden,
    404 => FailureKind.notFound,
    409 => FailureKind.conflict,
    422 => FailureKind.unprocessable,
    429 => FailureKind.rateLimited,
    final s? when s >= 500 => FailureKind.server,
    _ => FailureKind.unknown,
  };

  /// Erros de campo devolvidos no envelope 400 (`details: [{field, constraints}]`).
  Map<String, String> get fieldErrors {
    final raw = details;
    if (raw is! List) return const {};
    final result = <String, String>{};
    for (final item in raw) {
      if (item is Map && item['field'] is String) {
        final constraints = item['constraints'];
        result[item['field']
            as String] = constraints is List && constraints.isNotEmpty
            ? constraints.first.toString()
            : '';
      }
    }
    return result;
  }

  bool get isRetryable =>
      kind == FailureKind.network ||
      kind == FailureKind.server ||
      kind == FailureKind.rateLimited;

  @override
  String toString() =>
      'AppFailure($kind, status: $statusCode, code: $code, requestId: $requestId)';
}
