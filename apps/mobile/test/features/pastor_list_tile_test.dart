import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pastoral_app/core/theme/app_theme.dart';
import 'package:pastoral_app/features/network/domain/network_member.dart';
import 'package:pastoral_app/features/pastors/presentation/widgets/pastor_list_tile.dart';

/// Regressao: o card precisa mostrar nome, igreja e indicador factual.
void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  Widget host(NetworkMember member, {double width = 1000}) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: PastorListTile(pastor: member, onTap: () {}),
        ),
      ),
    ),
  );

  testWidgets('mostra nome, igreja e dias sem acompanhamento', (tester) async {
    await tester.pumpWidget(
      host(
        const NetworkMember(
          id: 'p1',
          pastoralName: 'Pr. Felipe Costa',
          status: 'ACTIVE',
          neverCared: false,
          daysSinceLastCare: 63,
          churchName: 'Igreja Uberlandia',
          city: 'Uberlandia',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pr. Felipe Costa'), findsOneWidget);
    expect(find.textContaining('Igreja Uberlandia'), findsOneWidget);
    expect(find.text('63 dias sem acompanhamento'), findsOneWidget);
  });

  testWidgets('funciona em largura estreita sem overflow', (tester) async {
    await tester.pumpWidget(
      host(
        const NetworkMember(
          id: 'p2',
          pastoralName: 'Pra. Ana Souza',
          status: 'ON_LEAVE',
          neverCared: true,
          churchName: 'Comunidade da Graca',
        ),
        width: 360,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pra. Ana Souza'), findsOneWidget);
    expect(find.text('Nunca acompanhado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
