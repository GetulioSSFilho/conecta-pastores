import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pastoral_app/core/utils/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('Formatters.careSince (indicadores factuais)', () {
    test('nunca acompanhado', () {
      expect(
        Formatters.careSince(days: null, neverCared: true),
        'Nunca acompanhado',
      );
    });

    test('conta dias sem julgamento', () {
      expect(
        Formatters.careSince(days: 63, neverCared: false),
        '63 dias sem acompanhamento',
      );
      expect(
        Formatters.careSince(days: 1, neverCared: false),
        '1 dia sem acompanhamento',
      );
      expect(
        Formatters.careSince(days: 0, neverCared: false),
        'Acompanhado hoje',
      );
    });

    test('nunca usa rotulos psicologicos', () {
      for (final days in [0, 1, 30, 63, 400]) {
        final text = Formatters.careSince(
          days: days,
          neverCared: false,
        ).toLowerCase();
        expect(text.contains('risco'), isFalse);
        expect(text.contains('crise'), isFalse);
      }
    });
  });

  group('Formatters.relativeDateTime', () {
    final now = DateTime(2026, 9, 11, 10);

    test('hoje, amanha e ontem', () {
      expect(
        Formatters.relativeDateTime(DateTime(2026, 9, 11, 19, 30), now: now),
        'Hoje, 19:30',
      );
      expect(
        Formatters.relativeDateTime(DateTime(2026, 9, 12, 9), now: now),
        'Amanhã, 09:00',
      );
      expect(
        Formatters.relativeDateTime(DateTime(2026, 9, 10, 8), now: now),
        'Ontem, 08:00',
      );
    });

    test('outras datas usam dia/mes', () {
      expect(
        Formatters.relativeDateTime(DateTime(2026, 9, 15, 14, 30), now: now),
        '15/09, 14:30',
      );
    });
  });

  test('pluralizacao', () {
    expect(Formatters.count(1, 'igreja', 'igrejas'), '1 igreja');
    expect(Formatters.count(3, 'igreja', 'igrejas'), '3 igrejas');
  });
}
