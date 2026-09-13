import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pastoral_app/features/auth/application/auth_controller.dart';
import 'package:pastoral_app/features/auth/presentation/login_screen.dart';
import 'package:pastoral_app/features/auth/presentation/landing_screen.dart';
import 'package:pastoral_app/features/auth/presentation/password_screens.dart';
import 'package:pastoral_app/features/dashboard/data/dashboard_providers.dart';
import 'package:pastoral_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:pastoral_app/features/dashboard/domain/dashboard_models.dart';
import 'package:pastoral_app/features/notifications/data/notifications_providers.dart';
import 'package:pastoral_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth.dart';
import '../support/test_users.dart';

Widget _app(AuthState state) => ProviderScope(
  retry: (_, _) => null,
  overrides: [
    authControllerProvider.overrideWith(() => FixedAuthController(state)),
    unreadNotificationsCountProvider.overrideWith((ref) async => 0),
    pastorDashboardProvider.overrideWith(
      (ref) async => const PastorDashboard(),
    ),
    latestAnnouncementsProvider.overrideWith((ref) async => const []),
  ],
  child: const PastoralApp(),
);

Future<void> _pumpLanding(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sem sessao, a entrada publica mostra boas-vindas', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AuthSignedOut()));
    await _pumpLanding(tester);
    expect(find.byType(LandingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets('restaurando sessao mostra splash sem trocar de rota', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AuthRestoring()));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('com sessao, abre o inicio', (tester) async {
    await tester.pumpWidget(_app(AuthSignedIn(testUser())));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('senha provisoria obriga troca antes de navegar', (tester) async {
    await tester.pumpWidget(
      _app(AuthSignedIn(testUser(mustChangePassword: true))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordScreen), findsOneWidget);
  });

  testWidgets('login valida campos antes de chamar a API', (tester) async {
    await tester.pumpWidget(_app(const AuthSignedOut()));
    await _pumpLanding(tester);
    await tester.tap(find.text('Fazer login'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
  });

  testWidgets('"Fale com sua liderança" explica como obter acesso', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AuthSignedOut()));
    await _pumpLanding(tester);
    await tester.tap(find.text('Fazer login'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contact-leadership')));
    await tester.pumpAndSettle();
    expect(find.text('Como obter acesso'), findsOneWidget);
  });
}
