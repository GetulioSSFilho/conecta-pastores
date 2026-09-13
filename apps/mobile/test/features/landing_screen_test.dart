import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pastoral_app/features/auth/presentation/landing_screen.dart';

void main() {
  testWidgets('entrada pública leva ao login', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const LandingScreen()),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Tela de login')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Conecta\nPastores'), findsOneWidget);
    expect(find.text('Fazer login'), findsOneWidget);
    expect(find.byType(Hero), findsOneWidget);

    final loginButton = find.byKey(const Key('landing-login'));
    expect(tester.getSize(loginButton).width, lessThanOrEqualTo(460));
    expect(tester.getTopLeft(loginButton).dy, lessThan(100));
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Tela de login'), findsOneWidget);
  });
}
