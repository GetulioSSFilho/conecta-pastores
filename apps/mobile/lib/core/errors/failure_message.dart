import 'app_failure.dart';

/// Mensagem amigavel para uma falha.
///
/// Usa `code` quando ha texto especifico; senao, a categoria. O texto do servidor
/// nunca e exibido como mensagem principal (pode vir tecnico ou sem acento).
/// TODO(i18n): migrar para ARB junto com as demais strings (docs/progress.md).
String failureMessage(AppFailure failure) {
  final byCode = switch (failure.code) {
    'INVALID_CREDENTIALS' => 'E-mail ou senha inválidos.',
    'ACCOUNT_LOCKED' =>
      'Conta bloqueada temporariamente por tentativas inválidas. Tente novamente em 15 minutos ou recupere a senha.',
    'ACCOUNT_DISABLED' => 'Esta conta está desativada. Fale com sua liderança.',
    'SESSION_REVOKED' ||
    'TOKEN_EXPIRED' => 'Sua sessão terminou. Entre novamente.',
    'OUT_OF_SCOPE' =>
      'Este registro está fora da sua área de responsabilidade.',
    'CONFIDENTIAL_ACCESS_DENIED' => 'Este registro tem acesso restrito.',
    'CYCLE_DETECTED' => 'Essa alteração criaria um ciclo na hierarquia.',
    _ => null,
  };
  if (byCode != null) return byCode;

  return switch (failure.kind) {
    FailureKind.validation => 'Verifique os dados informados.',
    FailureKind.unauthorized => 'Sua sessão terminou. Entre novamente.',
    FailureKind.forbidden => 'Você não tem permissão para acessar isto.',
    FailureKind.notFound => 'Não encontramos o que você procura.',
    FailureKind.conflict =>
      failure.message ?? 'Já existe um registro com esses dados.',
    FailureKind.unprocessable =>
      failure.message ?? 'Não foi possível concluir a operação.',
    FailureKind.rateLimited =>
      'Muitas tentativas em pouco tempo. Aguarde alguns minutos.',
    FailureKind.server => 'O servidor encontrou um problema. Tente novamente.',
    FailureKind.network =>
      'Sem conexão com o servidor. Verifique sua internet e tente novamente.',
    FailureKind.unknown => 'Algo deu errado. Tente novamente.',
  };
}

/// Mensagem para qualquer erro capturado (AppFailure ou inesperado).
String errorMessage(Object error) => error is AppFailure
    ? failureMessage(error)
    : 'Algo deu errado. Tente novamente.';
