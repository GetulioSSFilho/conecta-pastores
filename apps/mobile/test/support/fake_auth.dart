import 'package:pastoral_app/features/auth/application/auth_controller.dart';

/// Controlador de autenticacao com estado fixo.
///
/// Evita restaurar sessao (flutter_secure_storage nao tem plugin em testes)
/// e qualquer chamada a API.
class FixedAuthController extends AuthController {
  FixedAuthController(this.initial);

  final AuthState initial;

  @override
  AuthState build() => initial;
}
