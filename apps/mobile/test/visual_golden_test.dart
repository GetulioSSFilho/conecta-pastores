import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pastoral_app/core/theme/app_theme.dart';
import 'package:pastoral_app/features/auth/application/auth_controller.dart';
import 'package:pastoral_app/features/auth/presentation/login_screen.dart';

import 'support/fake_auth.dart';

/// Goldens das telas que não dependem de dados da API.
///
/// As telas integradas (dashboard, shell, mapa, formação, igrejas...) são
/// cobertas por testes de widget com providers falsos em test/features e
/// test/app, que verificam conteúdo em vez de pixels.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('captura login mobile', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => FixedAuthController(const AuthSignedOut()),
          ),
        ],
        child: _app(const LoginScreen()),
      ),
    );
    await _precacheImages(tester);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('goldens/login_mobile.png'),
    );
  });
}

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Decodifica todas as imagens locais antes da captura.
/// Sem isso o golden depende da ordem dos testes (cache de imagem aquecido ou nao).
Future<void> _precacheImages(WidgetTester tester) async {
  final element = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final images = manifest.listAssets().where(
      (a) => a.startsWith('assets/images/') && a.endsWith('.png'),
    );
    await Future.wait([
      for (final path in images) precacheImage(AssetImage(path), element),
    ]);
  });
  await tester.pumpAndSettle();
}
