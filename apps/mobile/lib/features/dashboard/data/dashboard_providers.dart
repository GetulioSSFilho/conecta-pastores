import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paginated.dart';
import '../../channel/domain/channel_post.dart';
import '../../network/domain/network_member.dart';
import '../domain/dashboard_models.dart';

/// Uma consulta por bloco do dashboard: cada secao carrega e falha de forma independente.

final pastorDashboardProvider = FutureProvider.autoDispose<PastorDashboard>((
  ref,
) async {
  return PastorDashboard.fromJson(
    await ref.watch(apiClientProvider).getJson('/reports/dashboard/pastor'),
  );
});

final leaderDashboardProvider = FutureProvider.autoDispose<LeaderDashboard>((
  ref,
) async {
  return LeaderDashboard.fromJson(
    await ref.watch(apiClientProvider).getJson('/reports/dashboard/leader'),
  );
});

final globalDashboardProvider = FutureProvider.autoDispose<GlobalDashboard>((
  ref,
) async {
  return GlobalDashboard.fromJson(
    await ref.watch(apiClientProvider).getJson('/reports/dashboard/global'),
  );
});

final countryDistributionProvider =
    FutureProvider.autoDispose<List<CountryDistribution>>((ref) async {
      final list = await ref
          .watch(apiClientProvider)
          .getList('/reports/distribution/countries');
      return list
          .cast<Map<String, dynamic>>()
          .map(CountryDistribution.fromJson)
          .toList();
    });

final careActivityProvider =
    FutureProvider.autoDispose<List<CareActivityPoint>>((ref) async {
      final list = await ref
          .watch(apiClientProvider)
          .getList('/reports/care/activity', query: {'weeks': 12});
      return list
          .cast<Map<String, dynamic>>()
          .map(CareActivityPoint.fromJson)
          .toList();
    });

/// Ultimos comunicados (fixados primeiro, ordem definida pela API).
final latestAnnouncementsProvider =
    FutureProvider.autoDispose<List<ChannelPostSummary>>((ref) async {
      final json = await ref
          .watch(apiClientProvider)
          .getJson('/channel', query: {'pageSize': 3});
      return Paginated.fromJson(json, ChannelPostSummary.fromJson).items;
    });

/// Pastores da rede ha mais tempo sem acompanhamento (nunca acompanhados primeiro).
final attentionPastorsProvider =
    FutureProvider.autoDispose<Paginated<NetworkMember>>((ref) async {
      final json = await ref
          .watch(apiClientProvider)
          .getJson(
            '/network',
            query: {
              'careOverdueDays': 30,
              'sortBy': 'lastCareAt',
              'sortOrder': 'asc',
              'pageSize': 5,
            },
          );
      return Paginated.fromJson(json, NetworkMember.fromJson);
    });

/// Invalida todos os blocos (pull-to-refresh).
void refreshDashboard(WidgetRef ref) {
  ref
    ..invalidate(pastorDashboardProvider)
    ..invalidate(leaderDashboardProvider)
    ..invalidate(globalDashboardProvider)
    ..invalidate(countryDistributionProvider)
    ..invalidate(careActivityProvider)
    ..invalidate(latestAnnouncementsProvider)
    ..invalidate(attentionPastorsProvider);
}
