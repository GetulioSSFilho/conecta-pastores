DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
int _int(Object? v) => (v as num?)?.toInt() ?? 0;
Map<String, dynamic>? _map(Object? v) => (v as Map?)?.cast<String, dynamic>();

class PersonRef {
  const PersonRef({required this.id, required this.name});

  static PersonRef? fromJson(Map<String, dynamic>? json) => json == null
      ? null
      : PersonRef(
          id: json['id'] as String,
          name: json['pastoralName'] as String? ?? '',
        );

  final String id;
  final String name;
}

class EventRef {
  const EventRef({
    required this.id,
    required this.title,
    required this.startsAt,
    this.endsAt,
  });

  static EventRef? fromJson(Map<String, dynamic>? json) => json == null
      ? null
      : EventRef(
          id: json['id'] as String,
          title: json['title'] as String? ?? '',
          startsAt: _date(json['startsAt'])!,
          endsAt: _date(json['endsAt']),
        );

  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
}

class ChurchRef {
  const ChurchRef({required this.id, required this.name, this.city});

  static ChurchRef? fromJson(Map<String, dynamic>? json) => json == null
      ? null
      : ChurchRef(
          id: json['id'] as String,
          name: json['name'] as String? ?? '',
          city: json['city'] as String?,
        );

  final String id;
  final String name;
  final String? city;
}

/// `GET /reports/dashboard/pastor` - sempre dados do proprio usuario.
class PastorDashboard {
  const PastorDashboard({
    this.nextEvent,
    this.church,
    this.leadership,
    this.unreadNotifications = 0,
    this.openRequests = 0,
    this.expiringDocuments = 0,
    this.trainingTotal = 0,
    this.trainingCompleted = 0,
    this.trainingProgressPct = 0,
  });

  factory PastorDashboard.fromJson(Map<String, dynamic> json) {
    final training = _map(json['training']) ?? const {};
    return PastorDashboard(
      nextEvent: EventRef.fromJson(_map(json['nextEvent'])),
      church: ChurchRef.fromJson(_map(json['church'])),
      leadership: PersonRef.fromJson(_map(json['leadership'])),
      unreadNotifications: _int(json['unreadNotifications']),
      openRequests: _int(json['openRequests']),
      expiringDocuments: _int(json['expiringDocuments']),
      trainingTotal: _int(training['total']),
      trainingCompleted: _int(training['completed']),
      trainingProgressPct: _int(training['progressPct']),
    );
  }

  final EventRef? nextEvent;
  final ChurchRef? church;
  final PersonRef? leadership;
  final int unreadNotifications;
  final int openRequests;
  final int expiringDocuments;
  final int trainingTotal;
  final int trainingCompleted;
  final int trainingProgressPct;

  int get trainingPending => trainingTotal - trainingCompleted;
}

class NextCare {
  const NextCare({
    required this.pastorId,
    required this.pastoralName,
    required this.nextCareAt,
  });

  final String pastorId;
  final String pastoralName;
  final DateTime nextCareAt;
}

/// `GET /reports/dashboard/leader`.
class LeaderDashboard {
  const LeaderDashboard({
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

  factory LeaderDashboard.fromJson(Map<String, dynamic> json) {
    final network = _map(json['network']) ?? const {};
    final care = _map(json['care']) ?? const {};
    return LeaderDashboard(
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
      nextCare: [
        for (final item
            in (json['nextCare'] as List? ?? const [])
                .cast<Map<String, dynamic>>())
          if (_date(item['nextCareAt']) != null)
            NextCare(
              pastorId: item['id'] as String,
              pastoralName: item['pastoralName'] as String? ?? '',
              nextCareAt: _date(item['nextCareAt'])!,
            ),
      ],
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
  final List<NextCare> nextCare;
}

/// `GET /reports/dashboard/global` - "global" dentro do escopo do usuario.
class GlobalDashboard {
  const GlobalDashboard({
    required this.totalPastors,
    required this.activePastors,
    required this.totalChurches,
    required this.countries,
    required this.regions,
    required this.newPastors,
  });

  factory GlobalDashboard.fromJson(Map<String, dynamic> json) =>
      GlobalDashboard(
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

class CountryDistribution {
  const CountryDistribution({
    required this.id,
    required this.code,
    required this.name,
    required this.pastors,
    required this.churches,
  });

  factory CountryDistribution.fromJson(Map<String, dynamic> json) =>
      CountryDistribution(
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

class CareActivityPoint {
  const CareActivityPoint({required this.weekStart, required this.count});

  factory CareActivityPoint.fromJson(Map<String, dynamic> json) =>
      CareActivityPoint(
        weekStart: _date(json['weekStart'])!,
        count: _int(json['count']),
      );

  final DateTime weekStart;
  final int count;
}
