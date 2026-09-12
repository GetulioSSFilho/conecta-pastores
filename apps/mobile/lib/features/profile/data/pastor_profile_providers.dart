import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paginated.dart';
import '../../network/domain/network_member.dart';
import '../domain/pastor_profile_models.dart';

/// Perfil 360: um provider por secao, carregado apenas quando a aba e aberta.
/// Cada chamada passa pela autorizacao da API (escopo + permissao).

final pastorSummaryProvider = FutureProvider.autoDispose
    .family<PastorSummary, String>((ref, id) async {
      return PastorSummary.fromJson(
        await ref.watch(apiClientProvider).getJson('/pastors/$id'),
      );
    });

final pastorMinistryProvider = FutureProvider.autoDispose
    .family<PastorMinistry, String>((ref, id) async {
      return PastorMinistry.fromJson(
        await ref.watch(apiClientProvider).getJson('/pastors/$id/ministry'),
      );
    });

final pastorLeadershipProvider = FutureProvider.autoDispose
    .family<List<LeadershipLink>, String>((ref, id) async {
      final json = await ref
          .watch(apiClientProvider)
          .getJson('/pastors/$id/leadership');
      return (json['chain'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(LeadershipLink.fromJson)
          .toList();
    });

class PastorNetworkSection {
  const PastorNetworkSection({
    required this.total,
    required this.direct,
    required this.maxDepth,
    required this.directReports,
  });

  final int total;
  final int direct;
  final int maxDepth;
  final List<NetworkMember> directReports;
}

final pastorNetworkProvider = FutureProvider.autoDispose
    .family<PastorNetworkSection, String>((ref, id) async {
      final json = await ref
          .watch(apiClientProvider)
          .getJson('/pastors/$id/network');
      final stats =
          (json['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
      return PastorNetworkSection(
        total: (stats['totalInNetwork'] as num?)?.toInt() ?? 0,
        direct: (stats['directReports'] as num?)?.toInt() ?? 0,
        maxDepth: (stats['maxDepth'] as num?)?.toInt() ?? 0,
        directReports: (json['directReports'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(NetworkMember.fromJson)
            .toList(),
      );
    });

final pastorCareTimelineProvider = FutureProvider.autoDispose
    .family<List<CareEntry>, String>((ref, id) async {
      final json = await ref
          .watch(apiClientProvider)
          .getJson('/care/timeline/$id', query: {'take': 30});
      return (json['entries'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CareEntry.fromJson)
          .toList();
    });

final pastorEventsProvider = FutureProvider.autoDispose
    .family<List<EventItem>, String>((ref, id) async {
      final from = DateTime.now().subtract(const Duration(days: 30));
      final json = await ref
          .watch(apiClientProvider)
          .getJson(
            '/events',
            query: {'pastorId': id, 'from': from, 'pageSize': 30},
          );
      return Paginated.fromJson(json, EventItem.fromJson).items;
    });

final pastorEnrollmentsProvider = FutureProvider.autoDispose
    .family<List<EnrollmentItem>, String>((ref, id) async {
      final json = await ref
          .watch(apiClientProvider)
          .getJson(
            '/training/enrollments',
            query: {'pastorId': id, 'pageSize': 50},
          );
      return Paginated.fromJson(json, EnrollmentItem.fromJson).items;
    });

final pastorDocumentsProvider = FutureProvider.autoDispose
    .family<List<DocumentItem>, String>((ref, id) async {
      final json = await ref
          .watch(apiClientProvider)
          .getJson('/documents', query: {'pastorId': id, 'pageSize': 50});
      return Paginated.fromJson(json, DocumentItem.fromJson).items;
    });

final pastorCredentialsProvider = FutureProvider.autoDispose
    .family<List<CredentialItem>, String>((ref, id) async {
      final json = await ref
          .watch(apiClientProvider)
          .getJson('/credentials', query: {'pastorId': id, 'pageSize': 20});
      return Paginated.fromJson(json, CredentialItem.fromJson).items;
    });

final pastorRequestsProvider = FutureProvider.autoDispose
    .family<List<RequestItem>, String>((ref, id) async {
      final json = await ref
          .watch(apiClientProvider)
          .getJson('/requests', query: {'pastorId': id, 'pageSize': 30});
      return Paginated.fromJson(json, RequestItem.fromJson).items;
    });

final pastorHistoryProvider = FutureProvider.autoDispose
    .family<List<HistoryItem>, String>((ref, id) async {
      final list = await ref
          .watch(apiClientProvider)
          .getList('/pastors/$id/history');
      return list
          .cast<Map<String, dynamic>>()
          .map(HistoryItem.fromJson)
          .toList();
    });

/// Detalhe de um acompanhamento (inclui anotacoes; a API aplica confidencialidade).
final careDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
      return ref.watch(apiClientProvider).getJson('/care/$id');
    });
