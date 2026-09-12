import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/paged_controller.dart';
import '../../../core/api/paginated.dart';
import '../domain/document_models.dart';

/// Filtros do acervo de documentos (aplicados no servidor).
class DocumentQuery {
  const DocumentQuery({
    this.search = '',
    this.category,
    this.pastorId,
    this.expiringInDays,
  });

  final String search;
  final DocumentCategory? category;
  final String? pastorId;

  /// Apenas documentos que vencem nos proximos N dias.
  final int? expiringInDays;

  bool get hasFilters =>
      search.isNotEmpty ||
      category != null ||
      pastorId != null ||
      expiringInDays != null;

  DocumentQuery copyWith({
    String? search,
    DocumentCategory? Function()? category,
    String? Function()? pastorId,
    int? Function()? expiringInDays,
  }) => DocumentQuery(
    search: search ?? this.search,
    category: category != null ? category() : this.category,
    pastorId: pastorId != null ? pastorId() : this.pastorId,
    expiringInDays: expiringInDays != null
        ? expiringInDays()
        : this.expiringInDays,
  );

  Map<String, dynamic> toApi(int page) => {
    'page': page,
    'pageSize': 25,
    'search': search,
    'category': category?.apiValue,
    'pastorId': pastorId,
    'expiringInDays': expiringInDays,
  };
}

class DocumentQueryNotifier extends Notifier<DocumentQuery> {
  @override
  DocumentQuery build() => const DocumentQuery();

  void set(DocumentQuery query) => state = query;
  void update(DocumentQuery Function(DocumentQuery) change) =>
      state = change(state);
}

final documentQueryProvider =
    NotifierProvider.autoDispose<DocumentQueryNotifier, DocumentQuery>(
      DocumentQueryNotifier.new,
    );

class DocumentsController extends PagedController<PastoralDocument> {
  @override
  Future<PagedResult<PastoralDocument>> build() {
    ref.watch(documentQueryProvider);
    return super.build();
  }

  @override
  Future<Paginated<PastoralDocument>> fetchPage(int page) async {
    final json = await ref
        .read(apiClientProvider)
        .getJson(
          '/documents',
          query: ref.read(documentQueryProvider).toApi(page),
        );
    return Paginated.fromJson(json, PastoralDocument.fromJson);
  }
}

final documentsProvider =
    AsyncNotifierProvider.autoDispose<
      DocumentsController,
      PagedResult<PastoralDocument>
    >(DocumentsController.new);

/// URL assinada de curta duracao. A API so emite depois de checar a permissao,
/// e registra auditoria quando o documento e restrito/confidencial.
final documentDownloadUrlProvider = Provider<Future<String?> Function(String)>((
  ref,
) {
  return (String documentId) async {
    final json = await ref
        .read(apiClientProvider)
        .getJson('/documents/$documentId/download');
    return json['url'] as String?;
  };
});
