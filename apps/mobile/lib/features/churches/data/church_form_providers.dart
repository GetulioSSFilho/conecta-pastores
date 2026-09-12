import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../pastors/domain/new_pastor.dart' show SelectOption;
import 'churches_providers.dart';

/// Dados de cadastro de igreja (`POST /churches`).
///
/// Obrigatorios na API: `code`, `name`, `countryId` e `city`.
class NewChurch {
  const NewChurch({
    required this.code,
    required this.name,
    required this.countryId,
    required this.city,
    this.type,
    this.status,
    this.regionId,
    this.parentId,
    this.address,
    this.postalCode,
    this.phone,
    this.email,
    this.latitude,
    this.longitude,
    this.foundedAt,
    this.membersEstimate,
  });

  final String code;
  final String name;
  final String countryId;
  final String city;
  final String? type;
  final String? status;
  final String? regionId;
  final String? parentId;
  final String? address;
  final String? postalCode;
  final String? phone;
  final String? email;
  final double? latitude;
  final double? longitude;
  final DateTime? foundedAt;
  final int? membersEstimate;

  static String? _text(String? value) {
    final clean = value?.trim();
    return (clean == null || clean.isEmpty) ? null : clean;
  }

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{
      'code': code.trim().toUpperCase(),
      'name': name.trim(),
      'countryId': countryId,
      'city': city.trim(),
      'type': type,
      'status': status,
      'regionId': regionId,
      'parentId': parentId,
      'address': _text(address),
      'postalCode': _text(postalCode),
      'phone': _text(phone),
      'email': _text(email),
      'latitude': latitude,
      'longitude': longitude,
      'foundedAt': foundedAt == null
          ? null
          : '${foundedAt!.year.toString().padLeft(4, '0')}-'
                '${foundedAt!.month.toString().padLeft(2, '0')}-'
                '${foundedAt!.day.toString().padLeft(2, '0')}',
      'membersEstimate': membersEstimate,
    };
    body.removeWhere((_, value) => value == null);
    return body;
  }
}

/// Igrejas que podem ser sede de outra (para campus e congregacoes).
final parentChurchOptionsProvider = FutureProvider.autoDispose
    .family<List<SelectOption>, String?>((ref, countryId) async {
      final json = await ref
          .watch(apiClientProvider)
          .getJson('/churches', query: {'countryId': countryId, 'pageSize': 100});
      final items = (json['data'] as List? ?? const []).cast<Map<String, dynamic>>();
      return items
          .map(
            (church) => SelectOption(
              id: church['id'] as String,
              label: church['name'] as String? ?? '',
              detail: church['city'] as String?,
            ),
          )
          .toList();
    });

/// Cadastra a igreja e devolve o id criado.
final createChurchProvider = Provider<Future<String> Function(NewChurch)>((ref) {
  return (NewChurch church) async {
    final response = await ref.read(apiClientProvider).post('/churches', body: church.toJson());
    final map = response is Map ? response.cast<String, dynamic>() : const <String, dynamic>{};
    final id = map['id'] as String? ?? '';
    ref.invalidate(churchesProvider);
    return id;
  };
});
