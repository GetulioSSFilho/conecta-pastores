import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastoral_app/app/shell/app_scaffold.dart';
import 'package:pastoral_app/core/theme/app_theme.dart';
import 'package:pastoral_app/features/auth/application/auth_controller.dart';
import 'package:pastoral_app/features/notifications/data/notifications_providers.dart';

import '../support/fake_auth.dart';
import '../support/test_users.dart';

/// A navegacao principal precisa ser operavel por leitor de tela:
/// cada destino e um botao com rotulo e acao de toque.
void main() {
  Widget host(String location) => ProviderScope(
    retry: (_, _) => null,
    overrides: [
      authControllerProvider.overrideWith(
        () => FixedAuthController(
          AuthSignedIn(testUser(permissions: supervisorPermissions)),
        ),
      ),
      unreadNotificationsCountProvider.overrideWith((ref) async => 2),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: AppScaffold(location: location, child: const Text('conteudo')),
    ),
  );

  Future<void> pumpAt(
    WidgetTester tester,
    double width, {
    String location = '/network',
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(location));
    await tester.pumpAndSettle();
  }

  testWidgets('sidebar (desktop) expõe destinos como botões acionáveis', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpAt(tester, 1400);

    expect(
      find.text('Minha Rede'),
      findsWidgets,
      reason: 'a sidebar precisa listar os destinos',
    );
    expect(find.text('Configurações'), findsWidgets);

    final data = tester
        .getSemantics(find.text('Minha Rede').first)
        .getSemanticsData();
    expect(data.label, contains('Minha Rede'));
    expect(
      data.flagsCollection.isButton,
      isTrue,
      reason: 'destino precisa ter papel de botão',
    );
    expect(
      data.hasAction(SemanticsAction.tap),
      isTrue,
      reason: 'destino precisa ser acionável',
    );
    handle.dispose();
  });

  testWidgets('rail (tablet) usa tooltip como rótulo do destino', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpAt(tester, 900);

    final finder = find.byTooltip('Minha Rede');
    expect(finder, findsOneWidget, reason: 'no rail o rótulo vem do tooltip');
    expect(
      tester
          .getSemantics(finder)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
      reason: 'destino do rail precisa ser acionável',
    );
    handle.dispose();
  });

  testWidgets('celular usa navegação inferior com rótulos', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAt(tester, 420, location: '/dashboard');

    expect(find.text('Início'), findsWidgets);
    expect(find.text('Perfil'), findsWidgets);
    handle.dispose();
  });

  testWidgets('celular abre menu lateral pelos destinos completos', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpAt(tester, 420, location: '/network');

    expect(find.byTooltip('Abrir menu'), findsOneWidget);
    await tester.tap(find.byTooltip('Abrir menu'));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('Pastores'), findsOneWidget);
    expect(find.text('Configurações'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('celular usa Mais quando a conta nao tem pastor vinculado', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authControllerProvider.overrideWith(
            () => FixedAuthController(
              AuthSignedIn(
                testUser(permissions: supervisorPermissions, pastorId: null),
              ),
            ),
          ),
          unreadNotificationsCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: AppScaffold(
            location: '/dashboard',
            child: const Text('conteudo'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mais'), findsWidgets);
    expect(find.text('Perfil'), findsNothing);
    handle.dispose();
  });
}
