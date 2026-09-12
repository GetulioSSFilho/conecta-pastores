import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paged_controller.dart';
import '../../../core/api/paginated.dart';
import '../domain/channel_post.dart';

/// Filtros do Canal (aplicados no servidor).
class ChannelQuery {
  const ChannelQuery({this.search = '', this.type, this.pinnedOnly = false});

  final String search;
  final String? type;
  final bool pinnedOnly;

  bool get hasFilters => search.isNotEmpty || type != null || pinnedOnly;

  ChannelQuery copyWith({
    String? search,
    String? Function()? type,
    bool? pinnedOnly,
  }) => ChannelQuery(
    search: search ?? this.search,
    type: type != null ? type() : this.type,
    pinnedOnly: pinnedOnly ?? this.pinnedOnly,
  );

  Map<String, dynamic> toApi(int page) => {
    'page': page,
    'pageSize': 20,
    'search': search,
    'type': type,
    if (pinnedOnly) 'pinnedOnly': true,
  };
}

class ChannelQueryNotifier extends Notifier<ChannelQuery> {
  @override
  ChannelQuery build() => const ChannelQuery();

  void set(ChannelQuery query) => state = query;
  void update(ChannelQuery Function(ChannelQuery) change) =>
      state = change(state);
}

final channelQueryProvider =
    NotifierProvider.autoDispose<ChannelQueryNotifier, ChannelQuery>(
      ChannelQueryNotifier.new,
    );

class ChannelFeedController extends PagedController<ChannelPostSummary> {
  @override
  Future<PagedResult<ChannelPostSummary>> build() {
    ref.watch(channelQueryProvider);
    return super.build();
  }

  @override
  Future<Paginated<ChannelPostSummary>> fetchPage(int page) async {
    final json = await ref
        .read(apiClientProvider)
        .getJson('/channel', query: ref.read(channelQueryProvider).toApi(page));
    return Paginated.fromJson(json, ChannelPostSummary.fromJson);
  }

  /// Reflete leitura/confirmacao na lista sem recarregar tudo.
  void markLocallyRead(String postId, {bool acknowledged = false}) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [
          for (final post in current.items)
            post.id == postId
                ? post.copyWith(
                    readAt: DateTime.now(),
                    acknowledged: acknowledged || post.acknowledged,
                  )
                : post,
        ],
      ),
    );
  }
}

final channelFeedProvider =
    AsyncNotifierProvider.autoDispose<
      ChannelFeedController,
      PagedResult<ChannelPostSummary>
    >(ChannelFeedController.new);

final channelPostProvider = FutureProvider.autoDispose
    .family<ChannelPostDetail, String>((ref, id) async {
      // Mantem o post em cache enquanto a tela de detalhe estiver aberta.
      final link = ref.keepAlive();
      ref.onDispose(link.close);
      return ChannelPostDetail.fromJson(
        await ref.watch(apiClientProvider).getJson('/channel/$id'),
      );
    });

/// Marca como lida (e confirma ciencia quando o post exige).
final markPostReadProvider =
    Provider<Future<void> Function(String, {bool acknowledged})>((ref) {
      return (String postId, {bool acknowledged = false}) async {
        await ref
            .read(apiClientProvider)
            .post(
              '/channel/$postId/read',
              body: {'acknowledged': acknowledged},
            );
        ref
            .read(channelFeedProvider.notifier)
            .markLocallyRead(postId, acknowledged: acknowledged);
        ref.invalidate(channelPostProvider(postId));
      };
    });
