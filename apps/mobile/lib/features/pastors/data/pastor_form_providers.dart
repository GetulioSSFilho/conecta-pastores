import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paginated.dart';
import '../../churches/data/churches_providers.dart';
import '../domain/new_pastor.dart';

/// Regioes de um pais (`GET /regions`). Vazio quando nenhum pais foi escolhido.
final regionOptionsProvider = FutureProvider.autoDispose
    .family<List<SelectOption>, String?>((ref, countryId) async {
      if (countryId == null) return const [];
      final json = await ref
          .watch(apiClientProvider)
          .getJson('/regions', query: {'countryId': countryId, 'pageSize': 100});
      final items = (json['data'] as List? ?? const []).cast<Map<String, dynamic>>();
      return items
          .map(
            (region) => SelectOption(
              id: region['id'] as String,
              label: region['name'] as String? ?? '',
              detail: region['code'] as String?,
            ),
          )
          .toList();
    });

/// Igrejas disponiveis para vinculo, dentro do escopo de quem cadastra.
final churchOptionsProvider = FutureProvider.autoDispose
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

/// Cargos ministeriais cadastrados (`GET /ministry-roles`).
final ministryRoleOptionsProvider = FutureProvider.autoDispose<List<SelectOption>>((ref) async {
  final list = await ref.watch(apiClientProvider).getList('/ministry-roles');
  return list
      .cast<Map<String, dynamic>>()
      .where((role) => role['isActive'] != false)
      .map(
        (role) => SelectOption(
          id: role['id'] as String,
          label: role['name'] as String? ?? '',
          detail: role['key'] as String?,
        ),
      )
      .toList();
});

/// Possiveis supervisores: pastores que o usuario ja pode enxergar.
final supervisorOptionsProvider = FutureProvider.autoDispose<List<SelectOption>>((ref) async {
  final json = await ref
      .watch(apiClientProvider)
      .getJson('/pastors', query: {'pageSize': 100, 'sortBy': 'pastoralName', 'sortOrder': 'asc'});
  final items = (json['data'] as List? ?? const []).cast<Map<String, dynamic>>();
  return items
      .map(
        (pastor) => SelectOption(
          id: pastor['id'] as String,
          label: pastor['pastoralName'] as String? ?? '',
          detail: (pastor['church'] as Map?)?['name'] as String?,
        ),
      )
      .toList();
});

/// Paises visiveis (reaproveita o provider de Igrejas).
final pastorCountryOptionsProvider = FutureProvider.autoDispose<List<SelectOption>>((ref) async {
  final countries = await ref.watch(countriesProvider.future);
  return countries
      .map((country) => SelectOption(id: country.id, label: country.name, detail: country.code))
      .toList();
});

/// Cadastra o pastor e devolve o id criado. A API valida permissao e escopo.
final createPastorProvider = Provider<Future<String> Function(NewPastor)>((ref) {
  return (NewPastor pastor) async {
    final response = await ref.read(apiClientProvider).post('/pastors', body: pastor.toJson());
    final map = response is Map ? response.cast<String, dynamic>() : const <String, dynamic>{};
    return map['id'] as String? ?? '';
  };
});

/// Usado pelas listas apos um cadastro, para nao mostrar dado velho.
void invalidatePastorLists(Ref ref) {
  ref.invalidate(supervisorOptionsProvider);
}

/// Paginacao reaproveitada pelos seletores que usam `Paginated`.
typedef OptionPage = Paginated<SelectOption>;
