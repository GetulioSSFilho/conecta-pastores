/// Pagina server-side no formato padrao da API (`{ data, meta }`).
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.hasNext,
  });

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final data = (json['data'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return Paginated(
      items: data.map(parse).toList(growable: false),
      page: (meta['page'] as num?)?.toInt() ?? 1,
      pageSize: (meta['pageSize'] as num?)?.toInt() ?? data.length,
      total: (meta['total'] as num?)?.toInt() ?? data.length,
      totalPages: (meta['totalPages'] as num?)?.toInt() ?? 1,
      hasNext: meta['hasNext'] as bool? ?? false,
    );
  }

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  final bool hasNext;

  bool get isEmpty => items.isEmpty;
}
