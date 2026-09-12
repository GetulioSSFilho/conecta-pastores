/// Pastor na rede do usuario (`GET /network`) com indicadores factuais.
class NetworkMember {
  const NetworkMember({
    required this.id,
    required this.pastoralName,
    required this.status,
    required this.neverCared,
    this.photoUrl,
    this.ministryTitle,
    this.lastCareAt,
    this.nextCareAt,
    this.daysSinceLastCare,
    this.daysUntilNextCare,
    this.churchId,
    this.churchName,
    this.city,
    this.regionName,
    this.countryCode,
    this.countryName,
    this.depth = 1,
    this.phone,
    this.whatsapp,
    this.email,
  });

  factory NetworkMember.fromJson(Map<String, dynamic> json) {
    final church = (json['church'] as Map?)?.cast<String, dynamic>();
    final region = (json['region'] as Map?)?.cast<String, dynamic>();
    final country = (json['country'] as Map?)?.cast<String, dynamic>();
    final indicators =
        (json['indicators'] as Map?)?.cast<String, dynamic>() ?? const {};
    return NetworkMember(
      id: json['id'] as String,
      pastoralName: json['pastoralName'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      ministryTitle: json['ministryTitle'] as String?,
      status: json['status'] as String? ?? 'ACTIVE',
      lastCareAt: _date(json['lastCareAt']),
      nextCareAt: _date(json['nextCareAt']),
      // Endpoints de arvore/perfil nao enviam `indicators`: calcula pela data.
      daysSinceLastCare:
          (indicators['daysSinceLastCare'] as num?)?.toInt() ??
          (_date(json['lastCareAt']) == null
              ? null
              : DateTime.now().difference(_date(json['lastCareAt'])!).inDays),
      daysUntilNextCare: (indicators['daysUntilNextCare'] as num?)?.toInt(),
      neverCared:
          indicators['neverCared'] as bool? ?? json['lastCareAt'] == null,
      churchId: church?['id'] as String?,
      churchName: church?['name'] as String?,
      city: (church?['city'] ?? json['city']) as String?,
      regionName: region?['name'] as String?,
      countryCode: country?['code'] as String?,
      countryName: country?['name'] as String?,
      depth: (json['depth'] as num?)?.toInt() ?? 1,
      phone: json['phoneE164'] as String?,
      whatsapp: json['whatsappE164'] as String?,
      email: json['email'] as String?,
    );
  }

  final String id;
  final String pastoralName;
  final String? photoUrl;
  final String? ministryTitle;
  final String status;
  final DateTime? lastCareAt;
  final DateTime? nextCareAt;
  final int? daysSinceLastCare;
  final int? daysUntilNextCare;
  final bool neverCared;
  final String? churchId;
  final String? churchName;
  final String? city;
  final String? regionName;
  final String? countryCode;
  final String? countryName;
  final int depth;
  final String? phone;
  final String? whatsapp;
  final String? email;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
