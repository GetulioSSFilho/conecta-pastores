import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configuracao de ambiente injetada em tempo de build.
///
/// Exemplo:
///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api
///   flutter build web --dart-define=API_BASE_URL=https://api.pastores.dominio.com/api
///
/// Nada de segredo aqui: tudo que vai para o cliente e publico.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.environment,
    required this.webPublicUrl,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3000/api',
    ),
    environment: String.fromEnvironment('APP_ENV', defaultValue: 'DEV'),
    webPublicUrl: String.fromEnvironment(
      'WEB_PUBLIC_URL',
      defaultValue: 'http://localhost:8080',
    ),
  );

  final String apiBaseUrl;
  final String environment;
  final String webPublicUrl;

  bool get isDev => environment == 'DEV';
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
