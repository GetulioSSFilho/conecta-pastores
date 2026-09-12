import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paginated.dart';

/// Igreja como opcao de filtro, com pais e regiao para derivar os demais filtros.
class ChurchOption {
  const ChurchOption({
    required this.id,
    required this.name,
    this.city,
    this.regionId,
    this.regionName,
    this.countryId,
    this.countryName,
  });

  factory ChurchOption.fromJson(Map<String, dynamic> json) {
    final region = (json['region'] as Map?)?.cast<String, dynamic>();
    final country = (json['country'] as Map?)?.cast<String, dynamic>();
    return ChurchOption(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      city: json['city'] as String?,
      regionId: region?['id'] as String?,
      regionName: region?['name'] as String?,
      countryId: country?['id'] as String?,
      countryName: country?['name'] as String?,
    );
  }

  final String id;
  final String name;
  final String? city;
  final String? regionId;
  final String? regionName;
  final String? countryId;
  final String? countryName;
}

typedef FilterOption = ({String id, String label});

/// Igrejas visiveis ao usuario (a API aplica o escopo). Base dos filtros de
/// igreja, regiao e pais, sem endpoints extras.
final scopedChurchOptionsProvider =
    FutureProvider.autoDispose<List<ChurchOption>>((ref) async {
      final json = await ref
          .watch(apiClientProvider)
          .getJson('/churches', query: {'pageSize': 100, 'sortBy': 'name'});
      final items = Paginated.fromJson(
        json,
        ChurchOption.fromJson,
      ).items.toList()..sort((a, b) => a.name.compareTo(b.name));
      return items;
    });

List<FilterOption> countriesOf(List<ChurchOption> churches) {
  final map = <String, String>{};
  for (final c in churches) {
    if (c.countryId != null) map[c.countryId!] = c.countryName ?? '';
  }
  return [for (final e in map.entries) (id: e.key, label: e.value)]
    ..sort((a, b) => a.label.compareTo(b.label));
}

List<FilterOption> regionsOf(List<ChurchOption> churches, {String? countryId}) {
  final map = <String, String>{};
  for (final c in churches) {
    if (c.regionId != null && (countryId == null || c.countryId == countryId)) {
      map[c.regionId!] = c.regionName ?? '';
    }
  }
  return [for (final e in map.entries) (id: e.key, label: e.value)]
    ..sort((a, b) => a.label.compareTo(b.label));
}
