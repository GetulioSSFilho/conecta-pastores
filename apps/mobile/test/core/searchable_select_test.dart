import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pastoral_app/core/widgets/searchable_select.dart';

void main() {
  testWidgets('select filtra as opcoes enquanto o usuario digita', (
    tester,
  ) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SearchableSelectFormField<String>(
              decoration: const InputDecoration(labelText: 'País'),
              initialValue: selected,
              items: const [
                DropdownMenuItem(value: 'br', child: Text('Brasil')),
                DropdownMenuItem(value: 'pt', child: Text('Portugal')),
                DropdownMenuItem(value: 'ao', child: Text('Angola')),
              ],
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SearchableSelectFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Brasil'), findsOneWidget);
    expect(find.text('Portugal'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'port');
    await tester.pump();
    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Brasil'), findsNothing);
    expect(find.text('Angola'), findsNothing);

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();
    expect(selected, 'pt');
  });

  testWidgets('select nao exibe o tipo dos widgets auxiliares', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchableSelectFormField<String>(
            initialValue: 'care',
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: [
              DropdownMenuItem(
                value: 'care',
                child: Row(
                  children: const [
                    Icon(Icons.favorite_outline),
                    SizedBox(width: 8),
                    Text('Acompanhamento'),
                  ],
                ),
              ),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SizedBox Acompanhamento'), findsNothing);
  });
}
