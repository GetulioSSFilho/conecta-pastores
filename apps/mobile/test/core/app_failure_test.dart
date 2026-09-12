import 'package:flutter_test/flutter_test.dart';
import 'package:pastoral_app/core/errors/app_failure.dart';
import 'package:pastoral_app/core/errors/failure_message.dart';

void main() {
  group('AppFailure.kindForStatus', () {
    test('diferencia todos os status tratados pela UI', () {
      expect(AppFailure.kindForStatus(400), FailureKind.validation);
      expect(AppFailure.kindForStatus(401), FailureKind.unauthorized);
      expect(AppFailure.kindForStatus(403), FailureKind.forbidden);
      expect(AppFailure.kindForStatus(404), FailureKind.notFound);
      expect(AppFailure.kindForStatus(409), FailureKind.conflict);
      expect(AppFailure.kindForStatus(422), FailureKind.unprocessable);
      expect(AppFailure.kindForStatus(429), FailureKind.rateLimited);
      expect(AppFailure.kindForStatus(500), FailureKind.server);
      expect(AppFailure.kindForStatus(503), FailureKind.server);
      expect(AppFailure.kindForStatus(null), FailureKind.unknown);
    });
  });

  test('fieldErrors le o envelope de validacao da API', () {
    const failure = AppFailure(
      kind: FailureKind.validation,
      details: [
        {
          'field': 'email',
          'constraints': ['E-mail invalido.'],
        },
        {'field': 'password', 'constraints': []},
      ],
    );
    expect(failure.fieldErrors, {'email': 'E-mail invalido.', 'password': ''});
  });

  test('mensagem usa o code estavel antes da categoria', () {
    const outOfScope = AppFailure(
      kind: FailureKind.forbidden,
      statusCode: 403,
      code: 'OUT_OF_SCOPE',
    );
    const genericForbidden = AppFailure(
      kind: FailureKind.forbidden,
      statusCode: 403,
    );
    expect(failureMessage(outOfScope), contains('fora da sua área'));
    expect(failureMessage(genericForbidden), contains('permissão'));
  });

  test('somente rede, servidor e rate limit sao repetiveis', () {
    expect(const AppFailure(kind: FailureKind.network).isRetryable, isTrue);
    expect(const AppFailure(kind: FailureKind.server).isRetryable, isTrue);
    expect(const AppFailure(kind: FailureKind.forbidden).isRetryable, isFalse);
  });
}
