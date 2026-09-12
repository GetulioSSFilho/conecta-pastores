import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Tipo da igreja (ChurchType da API).
enum ChurchType {
  main('MAIN', 'Sede', Icons.church_rounded),
  campus('CAMPUS', 'Campus', Icons.apartment_rounded),
  congregation('CONGREGATION', 'Congregação', Icons.groups_rounded),
  missionPoint('MISSION_POINT', 'Ponto de missão', Icons.flag_rounded);

  const ChurchType(this.apiValue, this.label, this.icon);

  final String apiValue;
  final String label;
  final IconData icon;

  static ChurchType fromApi(String? value) =>
      ChurchType.values.firstWhere((t) => t.apiValue == value, orElse: () => ChurchType.main);
}

/// Situacao cadastral da igreja (ChurchStatus da API).
enum ChurchStatus {
  active('ACTIVE', 'Ativa', AppColors.success),
  planting('PLANTING', 'Em implantação', AppColors.accent),
  inactive('INACTIVE', 'Inativa', AppColors.neutral),
  closed('CLOSED', 'Encerrada', AppColors.alert);

  const ChurchStatus(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  static ChurchStatus fromApi(String? value) =>
      ChurchStatus.values.firstWhere((s) => s.apiValue == value, orElse: () => ChurchStatus.active);
}

/// Numeros decimais do Prisma (latitude/longitude) chegam como string no JSON.
double? _toDouble(Object? value) => switch (value) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

int? _toInt(Object? value) => switch (value) {
  final num n => n.toInt(),
  final String s => int.tryParse(s),
  _ => null,
};

/// Pais ou regiao: mesmo formato `{id, code, name}` nas duas listas da API.
class GeoPlace {
  const GeoPlace({required this.id, required this.code, required this.name});

  factory GeoPlace.fromJson(Map<String, dynamic> json) => GeoPlace(
    id: json['id'] as String,
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );

  final String id;
  final String code;
  final String name;
}

/// Igreja como aparece na listagem (`GET /churches`).
class Church {
  const Church({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.status,
    required this.city,
    required this.pastorCount,
    required this.childrenCount,
    this.country,
    this.region,
    this.leadPastorId,
    this.leadPastorName,
    this.parentId,
  });

  factory Church.fromJson(Map<String, dynamic> json) {
    final counts = (json['_count'] as Map?)?.cast<String, dynamic>();
    final lead = (json['leadPastor'] as Map?)?.cast<String, dynamic>();
    final country = (json['country'] as Map?)?.cast<String, dynamic>();
    final region = (json['region'] as Map?)?.cast<String, dynamic>();
    return Church(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: ChurchType.fromApi(json['type'] as String?),
      status: ChurchStatus.fromApi(json['status'] as String?),
      city: json['city'] as String? ?? '',
      pastorCount: _toInt(counts?['pastors']) ?? 0,
      childrenCount: _toInt(counts?['children']) ?? 0,
      country: country == null ? null : GeoPlace.fromJson(country),
      region: region == null ? null : GeoPlace.fromJson(region),
      leadPastorId: lead?['id'] as String?,
      leadPastorName: lead?['pastoralName'] as String?,
      parentId: json['parentId'] as String?,
    );
  }

  final String id;
  final String code;
  final String name;
  final ChurchType type;
  final ChurchStatus status;
  final String city;
  final int pastorCount;
  final int childrenCount;
  final GeoPlace? country;
  final GeoPlace? region;
  final String? leadPastorId;
  final String? leadPastorName;
  final String? parentId;

  /// Local em uma linha: cidade, região e país, sem repetir vazio.
  String get placeText =>
      [city, ?region?.name, ?country?.name].where((p) => p.isNotEmpty).join(' · ');

  /// Fatos contados, nunca rótulo de desempenho.
  String get countsText {
    final pastors = '$pastorCount ${pastorCount == 1 ? 'pastor' : 'pastores'}';
    if (childrenCount == 0) return pastors;
    return '$pastors · $childrenCount ${childrenCount == 1 ? 'congregação' : 'congregações'}';
  }
}

/// Igreja detalhada (`GET /churches/:id`), com contato e vínculos.
class ChurchDetail {
  const ChurchDetail({
    required this.church,
    required this.children,
    this.address,
    this.postalCode,
    this.phone,
    this.email,
    this.timezone,
    this.foundedAt,
    this.membersEstimate,
    this.latitude,
    this.longitude,
    this.parentName,
    this.leadPastorEmail,
    this.leadPastorPhone,
  });

  factory ChurchDetail.fromJson(Map<String, dynamic> json) {
    final lead = (json['leadPastor'] as Map?)?.cast<String, dynamic>();
    final parent = (json['parent'] as Map?)?.cast<String, dynamic>();
    return ChurchDetail(
      church: Church.fromJson(json),
      children: (json['children'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(Church.fromJson)
          .toList(),
      address: json['address'] as String?,
      postalCode: json['postalCode'] as String?,
      // A API entrega o telefone da igreja normalizado em E.164.
      phone: json['phoneE164'] as String? ?? json['phone'] as String?,
      email: json['email'] as String?,
      timezone: json['timezone'] as String?,
      foundedAt: json['foundedAt'] is String ? DateTime.tryParse(json['foundedAt'] as String) : null,
      membersEstimate: _toInt(json['membersEstimate']),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      parentName: parent?['name'] as String?,
      leadPastorEmail: lead?['email'] as String?,
      leadPastorPhone: lead?['phoneE164'] as String?,
    );
  }

  final Church church;
  final List<Church> children;
  final String? address;
  final String? postalCode;
  final String? phone;
  final String? email;
  final String? timezone;
  final DateTime? foundedAt;
  final int? membersEstimate;
  final double? latitude;
  final double? longitude;
  final String? parentName;
  final String? leadPastorEmail;
  final String? leadPastorPhone;

  bool get hasCoordinates => latitude != null && longitude != null;
}

/// Pastor vinculado a igreja (`GET /churches/:id/pastors`).
class ChurchPastor {
  const ChurchPastor({
    required this.id,
    required this.pastoralName,
    this.ministryTitle,
    this.ministryRole,
    this.email,
    this.phone,
    this.photoUrl,
  });

  factory ChurchPastor.fromJson(Map<String, dynamic> json) => ChurchPastor(
    id: json['id'] as String,
    pastoralName: json['pastoralName'] as String? ?? '',
    ministryTitle: json['ministryTitle'] as String?,
    ministryRole: ((json['ministryRole'] as Map?)?.cast<String, dynamic>())?['name'] as String?,
    email: json['email'] as String?,
    phone: json['phoneE164'] as String?,
    photoUrl: json['photoUrl'] as String?,
  );

  final String id;
  final String pastoralName;
  final String? ministryTitle;
  final String? ministryRole;
  final String? email;
  final String? phone;
  final String? photoUrl;

  String get roleText => ministryTitle ?? ministryRole ?? 'Pastor';
}
