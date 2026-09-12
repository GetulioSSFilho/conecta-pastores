import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/report_models.dart';

/// Totais da rede. Exige `report.read_global`; sem ela a seção some (403).
final globalReportProvider = FutureProvider.autoDispose<GlobalReport>((ref) async {
  final json = await ref.watch(apiClientProvider).getJson('/reports/dashboard/global');
  return GlobalReport.fromJson(json);
});

/// Indicadores da rede do líder. Exige `report.read`.
final leaderReportProvider = FutureProvider.autoDispose<LeaderReport>((ref) async {
  final json = await ref.watch(apiClientProvider).getJson('/reports/dashboard/leader');
  return LeaderReport.fromJson(json);
});

final countryDistributionProvider =
    FutureProvider.autoDispose<List<CountryDistribution>>((ref) async {
      final list = await ref.watch(apiClientProvider).getList('/reports/distribution/countries');
      return list.cast<Map<String, dynamic>>().map(CountryDistribution.fromJson).toList()
        ..sort((a, b) => b.pastors.compareTo(a.pastors));
    });

/// Semanas exibidas no gráfico de acompanhamentos.
class CareActivityWeeks extends Notifier<int> {
  @override
  int build() => 12;

  void set(int weeks) => state = weeks;
}

final careActivityWeeksProvider =
    NotifierProvider.autoDispose<CareActivityWeeks, int>(CareActivityWeeks.new);

final careActivityProvider = FutureProvider.autoDispose<List<CareActivityPoint>>((ref) async {
  final weeks = ref.watch(careActivityWeeksProvider);
  final list = await ref
      .watch(apiClientProvider)
      .getList('/reports/care/activity', query: {'weeks': weeks});
  return list.cast<Map<String, dynamic>>().map(CareActivityPoint.fromJson).toList();
});
