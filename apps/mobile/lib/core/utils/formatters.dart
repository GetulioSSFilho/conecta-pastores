import 'package:intl/intl.dart';

/// Formatacao de datas e indicadores.
///
/// A API trabalha em UTC; aqui convertemos para o horario local do dispositivo.
/// TODO(timezone): usar o `timezone` do usuario quando diferir do dispositivo.
abstract final class Formatters {
  static final _dayMonth = DateFormat('dd/MM', 'pt_BR');
  static final _time = DateFormat('HH:mm', 'pt_BR');
  static final _fullDate = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');
  static final _monthShort = DateFormat('MMM', 'pt_BR');
  static final _date = DateFormat('dd/MM/yyyy', 'pt_BR');

  static String fullDate(DateTime date) {
    final text = _fullDate.format(date);
    return text[0].toUpperCase() + text.substring(1);
  }

  static String date(DateTime date) => _date.format(date.toLocal());
  static String dayMonth(DateTime date) => _dayMonth.format(date.toLocal());
  static String time(DateTime date) => _time.format(date.toLocal());
  static String monthShort(DateTime date) =>
      _monthShort.format(date.toLocal()).replaceAll('.', '').toUpperCase();
  static String day(DateTime date) =>
      date.toLocal().day.toString().padLeft(2, '0');

  /// "Hoje, 19:30" / "Amanhã, 10:00" / "Ontem, 08:00" / "15/09, 14:30".
  static String relativeDateTime(DateTime date, {DateTime? now}) {
    final local = date.toLocal();
    final today = _startOfDay(now ?? DateTime.now());
    final diff = _startOfDay(local).difference(today).inDays;
    final prefix = switch (diff) {
      0 => 'Hoje',
      1 => 'Amanhã',
      -1 => 'Ontem',
      _ => _dayMonth.format(local),
    };
    return '$prefix, ${_time.format(local)}';
  }

  /// Indicador factual de cuidado. Nunca adjetiva a pessoa.
  static String careSince({required int? days, required bool neverCared}) {
    if (neverCared || days == null) return 'Nunca acompanhado';
    if (days <= 0) return 'Acompanhado hoje';
    if (days == 1) return '1 dia sem acompanhamento';
    return '$days dias sem acompanhamento';
  }

  static String count(int value, String singular, String plural) =>
      '$value ${value == 1 ? singular : plural}';

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
}
