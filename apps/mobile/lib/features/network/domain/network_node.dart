/// No da arvore da rede (`GET /network/tree`).
class NetworkNode {
  const NetworkNode({
    required this.id,
    required this.pastoralName,
    required this.status,
    required this.depth,
    required this.children,
    this.photoUrl,
    this.churchName,
    this.lastCareAt,
    this.nextCareAt,
  });

  factory NetworkNode.fromJson(Map<String, dynamic> json) {
    final church = (json['church'] as Map?)?.cast<String, dynamic>();
    return NetworkNode(
      id: json['id'] as String,
      pastoralName: json['pastoralName'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      depth: (json['depth'] as num?)?.toInt() ?? 0,
      churchName: church?['name'] as String?,
      lastCareAt: json['lastCareAt'] is String
          ? DateTime.tryParse(json['lastCareAt'] as String)
          : null,
      nextCareAt: json['nextCareAt'] is String
          ? DateTime.tryParse(json['nextCareAt'] as String)
          : null,
      children: [
        for (final child
            in (json['children'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          NetworkNode.fromJson(child),
      ],
    );
  }

  final String id;
  final String pastoralName;
  final String? photoUrl;
  final String status;
  final int depth;
  final String? churchName;
  final DateTime? lastCareAt;
  final DateTime? nextCareAt;
  final List<NetworkNode> children;

  int? get daysSinceLastCare =>
      lastCareAt == null ? null : DateTime.now().difference(lastCareAt!).inDays;

  /// Total de pessoas abaixo deste no.
  int get descendantCount =>
      children.fold(children.length, (sum, c) => sum + c.descendantCount);
}
