import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:pastoral_app/core/theme/app_theme.dart';
import 'package:pastoral_app/features/network/data/network_providers.dart';
import 'package:pastoral_app/features/network/domain/network_member.dart';
import 'package:pastoral_app/features/network/presentation/my_network_screen.dart';
import 'package:pastoral_app/features/pastors/presentation/widgets/pastor_list_tile.dart';

Widget _app() {
  final router = GoRouter(
    initialLocation: '/network?view=tree',
    routes: [
      GoRoute(
        path: '/network',
        builder: (context, state) => const Scaffold(body: MyNetworkScreen()),
      ),
    ],
  );

  return ProviderScope(
    retry: (_, _) => null,
    overrides: [
      networkSummaryProvider.overrideWith(
        (ref) async => const NetworkSummary(
          total: 42,
          direct: 2,
          neverCared: 1,
          overdue30: 1,
        ),
      ),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('organograma inicia no presidente e permite expansão por nível', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Minha Rede'), findsOneWidget);
    expect(find.text('42 pastores'), findsOneWidget);
    expect(find.text('Buscar pastor...'), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('> 30 dias'), findsOneWidget);
    expect(find.text('Esta semana'), findsOneWidget);
    expect(find.text('Pr. André Valadão'), findsOneWidget);
    expect(find.text('Pr. Rodinei Medeiros'), findsOneWidget);
    expect(find.text('Pra. Renata Almeida'), findsOneWidget);
    expect(find.text('Regional · RMBH'), findsNothing);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).minScale,
      closeTo(0.35, 0.001),
    );
    expect(find.byTooltip('Aumentar zoom'), findsOneWidget);
    expect(find.byTooltip('Diminuir zoom'), findsOneWidget);
    expect(find.byTooltip('Redefinir zoom'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Expandir Pr. Rodinei Medeiros'));
    await tester.pumpAndSettle();
    expect(find.text('Regional · RMBH'), findsOneWidget);
    expect(find.bySemanticsLabel('Expandir Pr. João Silva'), findsOneWidget);
  });

  testWidgets('indicadores longos da lista não causam overflow no celular', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final pastor = NetworkMember(
      id: 'pastor-1',
      pastoralName: 'Pr. Alexandre de Oliveira',
      status: 'ACTIVE',
      neverCared: false,
      daysSinceLastCare: 26,
      nextCareAt: DateTime(2026, 9, 16, 16, 46),
      churchName: 'Igreja Vida em Orlando',
      city: 'Orlando',
      depth: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PastorListTile(pastor: pastor, showDepth: true, onTap: _noop),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
