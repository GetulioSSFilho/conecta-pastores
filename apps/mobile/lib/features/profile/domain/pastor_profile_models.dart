DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
Map<String, dynamic> _map(Object? v) =>
    (v as Map?)?.cast<String, dynamic>() ?? const {};
String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
String _name(Map<String, dynamic> m) =>
    '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();

/// Secao RESUMO (`GET /pastors/:id`).
class PastorSummary {
  const PastorSummary({
    required this.id,
    required this.pastoralName,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.neverCared,
    this.photoUrl,
    this.ministryTitle,
    this.ministryRoleName,
    this.joinedAt,
    this.email,
    this.phone,
    this.whatsapp,
    this.birthDate,
    this.maritalStatus,
    this.spouseName,
    this.city,
    this.address,
    this.regionName,
    this.countryName,
    this.biography,
    this.adminNotes,
    this.lastCareAt,
    this.nextCareAt,
    this.daysSinceLastCare,
    this.userEmail,
    this.userLastLoginAt,
  });

  factory PastorSummary.fromJson(Map<String, dynamic> json) {
    final indicators = _map(json['indicators']);
    final user = _map(json['user']);
    return PastorSummary(
      id: json['id'] as String,
      pastoralName: json['pastoralName'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      photoUrl: _str(json['photoUrl']),
      ministryTitle: _str(json['ministryTitle']),
      ministryRoleName: _str(_map(json['ministryRole'])['name']),
      joinedAt: _date(json['joinedAt']),
      email: _str(json['email']),
      phone: _str(json['phoneE164']),
      whatsapp: _str(json['whatsappE164']),
      birthDate: _date(json['birthDate']),
      maritalStatus: _str(json['maritalStatus']),
      spouseName: _str(json['spouseName']),
      city: _str(json['city']),
      address: _str(json['address']),
      regionName: _str(_map(json['region'])['name']),
      countryName: _str(_map(json['country'])['name']),
      biography: _str(json['biography']),
      adminNotes: _str(json['adminNotes']),
      lastCareAt: _date(json['lastCareAt']),
      nextCareAt: _date(json['nextCareAt']),
      daysSinceLastCare: (indicators['daysSinceLastCare'] as num?)?.toInt(),
      neverCared:
          indicators['neverCared'] as bool? ?? json['lastCareAt'] == null,
      userEmail: _str(user['email']),
      userLastLoginAt: _date(user['lastLoginAt']),
    );
  }

  final String id;
  final String pastoralName;
  final String firstName;
  final String lastName;
  final String status;
  final String? photoUrl;
  final String? ministryTitle;
  final String? ministryRoleName;
  final DateTime? joinedAt;
  final String? email;
  final String? phone;
  final String? whatsapp;
  final DateTime? birthDate;
  final String? maritalStatus;
  final String? spouseName;
  final String? city;
  final String? address;
  final String? regionName;
  final String? countryName;
  final String? biography;
  final String? adminNotes;
  final DateTime? lastCareAt;
  final DateTime? nextCareAt;
  final int? daysSinceLastCare;
  final bool neverCared;
  final String? userEmail;
  final DateTime? userLastLoginAt;

  String get location =>
      [city, regionName, countryName].whereType<String>().join(' · ');

  String? get maritalLabel => switch (maritalStatus) {
    'SINGLE' => 'Solteiro(a)',
    'MARRIED' => 'Casado(a)',
    'WIDOWED' => 'Viúvo(a)',
    'DIVORCED' => 'Divorciado(a)',
    'OTHER' => 'Outro',
    _ => null,
  };
}

/// Secao MINISTERIO (`GET /pastors/:id/ministry`).
class PastorMinistry {
  const PastorMinistry({
    this.ministryTitle,
    this.roleName,
    this.joinedAt,
    this.ordainedAt,
    this.churchId,
    this.churchName,
    this.churchType,
    this.churchCity,
    this.churchRegion,
    this.churchCountry,
    this.leadsChurchName,
  });

  factory PastorMinistry.fromJson(Map<String, dynamic> json) {
    final church = _map(json['church']);
    return PastorMinistry(
      ministryTitle: _str(json['ministryTitle']),
      roleName: _str(_map(json['ministryRole'])['name']),
      joinedAt: _date(json['joinedAt']),
      ordainedAt: _date(json['ordainedAt']),
      churchId: _str(church['id']),
      churchName: _str(church['name']),
      churchType: _str(church['type']),
      churchCity: _str(church['city']),
      churchRegion: _str(_map(church['region'])['name']),
      churchCountry: _str(_map(church['country'])['name']),
      leadsChurchName: _str(_map(json['leadsChurch'])['name']),
    );
  }

  final String? ministryTitle;
  final String? roleName;
  final DateTime? joinedAt;
  final DateTime? ordainedAt;
  final String? churchId;
  final String? churchName;
  final String? churchType;
  final String? churchCity;
  final String? churchRegion;
  final String? churchCountry;
  final String? leadsChurchName;

  String? get churchTypeLabel => switch (churchType) {
    'MAIN' => 'Igreja sede',
    'CAMPUS' => 'Campus',
    'CONGREGATION' => 'Congregação',
    'MISSION_POINT' => 'Ponto missionário',
    _ => null,
  };
}

/// Elo da cadeia de lideranca (`GET /pastors/:id/leadership`).
class LeadershipLink {
  const LeadershipLink({
    required this.depth,
    required this.pastorId,
    required this.pastoralName,
    this.photoUrl,
    this.churchName,
  });

  factory LeadershipLink.fromJson(Map<String, dynamic> json) {
    final ancestor = _map(json['ancestor']);
    return LeadershipLink(
      depth: (json['depth'] as num?)?.toInt() ?? 1,
      pastorId: ancestor['id'] as String,
      pastoralName: ancestor['pastoralName'] as String? ?? '',
      photoUrl: _str(ancestor['photoUrl']),
      churchName: _str(_map(ancestor['church'])['name']),
    );
  }

  final int depth;
  final String pastorId;
  final String pastoralName;
  final String? photoUrl;
  final String? churchName;
}

/// Nó da árvore de descendentes (`GET /network/tree`).
///
/// O perfil combina este ramo com a cadeia de ancestrais para apresentar um
/// organograma centrado no pastor consultado.
class PastorHierarchyNode {
  const PastorHierarchyNode({
    required this.id,
    required this.pastoralName,
    this.photoUrl,
    this.ministryTitle,
    this.churchName,
    this.children = const [],
  });

  factory PastorHierarchyNode.fromJson(Map<String, dynamic> json) {
    final church = _map(json['church']);
    return PastorHierarchyNode(
      id: json['id'] as String,
      pastoralName: json['pastoralName'] as String? ?? '',
      photoUrl: _str(json['photoUrl']),
      ministryTitle: _str(json['ministryTitle']),
      churchName: _str(church['name']),
      children: (json['children'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                PastorHierarchyNode.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final String pastoralName;
  final String? photoUrl;
  final String? ministryTitle;
  final String? churchName;
  final List<PastorHierarchyNode> children;

  String get detail => [
    ministryTitle,
    churchName,
  ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
}

class PastorHierarchy {
  const PastorHierarchy({required this.ancestors, this.descendants});

  final List<LeadershipLink> ancestors;
  final PastorHierarchyNode? descendants;
}

/// Registro de acompanhamento na linha do tempo.
class CareEntry {
  const CareEntry({
    required this.id,
    required this.occurredAt,
    required this.status,
    required this.summary,
    required this.confidentiality,
    required this.typeName,
    this.typeColor,
    this.nextAction,
    this.nextCareAt,
    this.performedByName,
  });

  factory CareEntry.fromJson(Map<String, dynamic> json) {
    final type = _map(json['type']);
    return CareEntry(
      id: json['id'] as String,
      occurredAt: _date(json['occurredAt'])!,
      status: json['status'] as String? ?? 'DONE',
      summary: json['summary'] as String? ?? '',
      confidentiality: json['confidentiality'] as String? ?? 'NORMAL',
      typeName: type['name'] as String? ?? 'Acompanhamento',
      typeColor: _str(type['color']),
      nextAction: _str(json['nextAction']),
      nextCareAt: _date(json['nextCareAt']),
      performedByName: json['performedBy'] == null
          ? null
          : _name(_map(json['performedBy'])),
    );
  }

  final String id;
  final DateTime occurredAt;
  final String status;
  final String summary;
  final String confidentiality;
  final String typeName;
  final String? typeColor;
  final String? nextAction;
  final DateTime? nextCareAt;
  final String? performedByName;
}

class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.type,
    required this.startsAt,
    this.location,
    this.meetingUrl,
  });

  factory EventItem.fromJson(Map<String, dynamic> json) => EventItem(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    type: json['type'] as String? ?? 'OTHER',
    startsAt: _date(json['startsAt'])!,
    location: _str(json['location']),
    meetingUrl: _str(json['meetingUrl']),
  );

  final String id;
  final String title;
  final String type;
  final DateTime startsAt;
  final String? location;
  final String? meetingUrl;
}

class EnrollmentItem {
  const EnrollmentItem({
    required this.id,
    required this.trainingTitle,
    required this.status,
    required this.progressPct,
    this.dueAt,
    this.completedAt,
  });

  factory EnrollmentItem.fromJson(Map<String, dynamic> json) => EnrollmentItem(
    id: json['id'] as String,
    trainingTitle: _map(json['training'])['title'] as String? ?? '',
    status: json['status'] as String? ?? 'ENROLLED',
    progressPct: (json['progressPct'] as num?)?.toInt() ?? 0,
    dueAt: _date(json['dueAt']),
    completedAt: _date(json['completedAt']),
  );

  final String id;
  final String trainingTitle;
  final String status;
  final int progressPct;
  final DateTime? dueAt;
  final DateTime? completedAt;
}

class DocumentItem {
  const DocumentItem({
    required this.id,
    required this.title,
    required this.category,
    required this.confidentiality,
    this.expiresAt,
    this.sizeBytes,
  });

  factory DocumentItem.fromJson(Map<String, dynamic> json) => DocumentItem(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    category: json['category'] as String? ?? 'OTHER',
    confidentiality: json['confidentiality'] as String? ?? 'NORMAL',
    expiresAt: _date(json['expiresAt']),
    sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
  );

  final String id;
  final String title;
  final String category;
  final String confidentiality;
  final DateTime? expiresAt;
  final int? sizeBytes;

  String get categoryLabel => switch (category) {
    'PASTORAL_DOCUMENT' => 'Documento pastoral',
    'CERTIFICATE' => 'Certificado',
    'MINISTERIAL_DOCUMENT' => 'Documento ministerial',
    'AUTHORIZATION' => 'Autorização',
    'IDENTIFICATION' => 'Identificação',
    _ => 'Documento',
  };
}

class CredentialItem {
  const CredentialItem({
    required this.id,
    required this.number,
    required this.type,
    required this.status,
    required this.issuedAt,
    this.expiresAt,
  });

  factory CredentialItem.fromJson(Map<String, dynamic> json) => CredentialItem(
    id: json['id'] as String,
    number: json['number'] as String? ?? '',
    type: json['type'] as String? ?? 'OTHER',
    status: json['status'] as String? ?? 'PENDING',
    issuedAt: _date(json['issuedAt'])!,
    expiresAt: _date(json['expiresAt']),
  );

  final String id;
  final String number;
  final String type;
  final String status;
  final DateTime issuedAt;
  final DateTime? expiresAt;

  String get typeLabel => switch (type) {
    'ORDINATION' => 'Ordenação',
    'MINISTERIAL' => 'Ministerial',
    'MISSIONARY' => 'Missionária',
    'TEMPORARY' => 'Temporária',
    _ => 'Credencial',
  };

  String get statusLabel => switch (status) {
    'ACTIVE' => 'Ativa',
    'EXPIRED' => 'Vencida',
    'REVOKED' => 'Revogada',
    _ => 'Pendente',
  };
}

class RequestItem {
  const RequestItem({
    required this.id,
    required this.number,
    required this.subject,
    required this.status,
    required this.createdAt,
    this.categoryName,
  });

  factory RequestItem.fromJson(Map<String, dynamic> json) => RequestItem(
    id: json['id'] as String,
    number: (json['number'] as num?)?.toInt() ?? 0,
    subject: json['subject'] as String? ?? '',
    status: json['status'] as String? ?? 'OPEN',
    createdAt: _date(json['createdAt'])!,
    categoryName: _str(_map(json['category'])['name']),
  );

  final String id;
  final int number;
  final String subject;
  final String status;
  final DateTime createdAt;
  final String? categoryName;

  String get statusLabel => switch (status) {
    'OPEN' => 'Aberta',
    'IN_PROGRESS' => 'Em andamento',
    'WAITING' => 'Aguardando',
    'RESOLVED' => 'Resolvida',
    'CLOSED' => 'Encerrada',
    _ => status,
  };
}

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.action,
    required this.createdAt,
    this.userName,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'] as String,
    action: json['action'] as String? ?? '',
    createdAt: _date(json['createdAt'])!,
    userName: json['user'] == null ? null : _name(_map(json['user'])),
  );

  final String id;
  final String action;
  final DateTime createdAt;
  final String? userName;

  String get actionLabel => switch (action) {
    'CREATE' => 'Cadastro criado',
    'UPDATE' => 'Dados atualizados',
    'DELETE' => 'Cadastro removido',
    'SUPERVISOR_CHANGE' => 'Supervisor alterado',
    'READ_CONFIDENTIAL' => 'Informação confidencial acessada',
    _ => action,
  };
}
