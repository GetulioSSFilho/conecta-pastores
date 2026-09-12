import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastoral_app/core/theme/app_theme.dart';
import 'package:pastoral_app/features/churches/data/churches_providers.dart';
import 'package:pastoral_app/features/churches/domain/church_models.dart';
import 'package:pastoral_app/features/map/data/map_providers.dart';
import 'package:pastoral_app/features/map/domain/map_models.dart';
import 'package:pastoral_app/features/map/presentation/church_map_screen.dart';

const _pontos = [
  ChurchMapPoint(
    id: 'c1',
    name: 'Igreja Belo Horizonte',
    city: 'Belo Horizonte',
    latitude: -19.9167,
    longitude: -43.9345,
    countryCode: 'BR',
    pastorCount: 5,
  ),
  ChurchMapPoint(
    id: 'c2',
    name: 'Igreja Luanda',
    city: 'Luanda',
    latitude: -8.8166,
    longitude: 13.2625,
    countryCode: 'AO',
    pastorCount: 3,
  ),
];

const _paises = [
  GeoPlace(id: 'br', code: 'BR', name: 'Brasil'),
  GeoPlace(id: 'ao', code: 'AO', name: 'Angola'),
];

Widget _app({
  List<ChurchMapPoint> pontos = _pontos,
  List<GeoPlace> paises = _paises,
}) => ProviderScope(
  retry: (_, _) => null,
  overrides: [
    churchMapProvider.overrideWith((ref) async => pontos),
    countriesProvider.overrideWith((ref) async => paises),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: ChurchMapScreen()),
  ),
);

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1400, 1400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('mapa mostra as igrejas do escopo e o filtro de países', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('2 igrejas localizadas'), findsOneWidget);
    expect(find.text('Todos os países'), findsOneWidget);
    expect(find.text('Brasil'), findsOneWidget);
    // Cada marcador mostra a quantidade de pastores vinculados.
    expect(find.text('5'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('tocar no marcador revela a igreja com dados factuais', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    expect(find.text('Igreja Belo Horizonte'), findsOneWidget);
    expect(find.text('Belo Horizonte · 5 pastores'), findsOneWidget);
    expect(find.text('Abrir'), findsOneWidget);
  });

  testWidgets('sem coordenadas no escopo, o mapa explica o vazio', (tester) async {
    await tester.pumpWidget(_app(pontos: const []));
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhuma igreja com coordenadas no seu escopo.'),
      findsOneWidget,
    );
  });

  testWidgets('filtro de país não aparece quando só há um país visível', (tester) async {
    await tester.pumpWidget(
      _app(paises: const [GeoPlace(id: 'br', code: 'BR', name: 'Brasil')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todos os países'), findsNothing);
  });
}
