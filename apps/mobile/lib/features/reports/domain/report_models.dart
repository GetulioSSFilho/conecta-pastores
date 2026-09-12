/// Totais da rede dentro do escopo (`GET /reports/dashboard/global`).
class GlobalReport {
  const GlobalReport({
    required this.totalPastors,
    required this.activePastors,
    required this.totalChurches,
    required this.countries,
    required this.regions,
    required this.newPastors,
  });

  factory GlobalReport.fromJson(Map<String, dynamic> json) => GlobalReport(
    totalPastors: _int(json['totalPastors']),
    activePastors: _int(json['activePastors']),
    totalChurches: _int(json['totalChurches']),
    countries: _int(json['countries']),
    regions: _int(json['regions']),
    newPastors: _int(json['newPastors']),
  );

  final int totalPastors;
  final int activePastors;
  final int totalChurches;
  final int countries;
  final int regions;
  final int newPastors;
}

/// Indicadores da rede do líder (`GET /reports/dashboard/leader`).
///
/// Todos são fatos contados — nunca rótulo sobre a pessoa.
class LeaderReport {
  const LeaderReport({
    required this.totalInNetwork,
    required this.activePastors,
    required this.directReports,
    required this.neverCared,
    required this.careOverdue30Days,
    required this.upcomingCareNext7Days,
    required this.careToday,
    required this.careThisWeek,
    required this.withoutCareOver30Days,
    required this.openRequests,
    required this.nextCare,
  });

  factory LeaderReport.fromJson(Map<String, dynamic> json) {
    final network = (json['network'] as Map?)?.cast<String, dynamic>() ?? const {};
    final care = (json['care'] as Map?)?.cast<String, dynamic>() ?? const {};
    return LeaderReport(
      totalInNetwork: _int(network['totalInNetwork']),
      activePastors: _int(network['activePastors']),
      directReports: _int(network['directReports']),
      neverCared: _int(network['neverCared']),
      careOverdue30Days: _int(network['careOverdue30Days']),
      upcomingCareNext7Days: _int(network['upcomingCareNext7Days']),
      careToday: _int(care['today']),
      careThisWeek: _int(care['thisWeek']),
      withoutCareOver30Days: _int(care['withoutCareOver30Days']),
      openRequests: _int(json['openRequests']),
      nextCare: (json['nextCare'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(NextCareItem.fromJson)
          .toList(),
    );
  }

  final int totalInNetwork;
  final int activePastors;
  final int directReports;
  final int neverCared;
  final int careOverdue30Days;
  final int upcomingCareNext7Days;
  final int careToday;
  final int careThisWeek;
  final int withoutCareOver30Days;
  final int openRequests;
  final List<NextCareItem> nextCare;
}

class NextCareItem {
  const NextCareItem({required this.pastorId, required this.pastoralName, this.nextCareAt});

  factory NextCareItem.fromJson(Map<String, dynamic> json) => NextCareItem(
    pastorId: json['id'] as String,
    pastoralName: json['pastoralName'] as String? ?? '',
    nextCareAt: json['nextCareAt'] is String
        ? DateTime.tryParse(json['nextCareAt'] as String)
        : null,
  );

  final String pastorId;
  final String pastoralName;
  final DateTime? nextCareAt;
}

/// Pastores e igrejas por país (`GET /reports/distribution/countries`).
class CountryDistribution {
  const CountryDistribution({
    required this.id,
    required this.code,
    required this.name,
    required this.pastors,
    required this.churches,
  });

  factory CountryDistribution.fromJson(Map<String, dynamic> json) => CountryDistribution(
    id: json['id'] as String,
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    pastors: _int(json['pastors']),
    churches: _int(json['churches']),
  );

  final String id;
  final String code;
  final String name;
  final int pastors;
  final int churches;
}

/// Acompanhamentos por semana (`GET /reports/care/activity`).
class CareActivityPoint {
  const CareActivityPoint({required this.weekStart, required this.count});

  factory CareActivityPoint.fromJson(Map<String, dynamic> json) => CareActivityPoint(
    weekStart: DateTime.parse(json['weekStart'] as String),
    count: _int(json['count']),
  );

  final DateTime weekStart;
  final int count;
}

int _int(Object? value) => switch (value) {
  final num n => n.toInt(),
  final String s => int.tryParse(s) ?? 0,
  _ => 0,
};
