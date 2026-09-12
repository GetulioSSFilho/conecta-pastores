import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/map_models.dart';

/// Pais selecionado no mapa (null = todos os que o usuario enxerga).
class MapCountryFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? countryId) => state = countryId;
}

final mapCountryFilterProvider =
    NotifierProvider.autoDispose<MapCountryFilter, String?>(MapCountryFilter.new);

final churchMapProvider = FutureProvider.autoDispose<List<ChurchMapPoint>>((ref) async {
  final countryId = ref.watch(mapCountryFilterProvider);
  final list = await ref
      .watch(apiClientProvider)
      .getList('/churches/map', query: {'countryId': countryId});
  return list.cast<Map<String, dynamic>>().map(ChurchMapPoint.fromJson).toList();
});
