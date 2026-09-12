import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Tipo da formacao (TrainingKind da API).
enum TrainingKind {
  course('COURSE', 'Curso', Icons.school_outlined),
  training('TRAINING', 'Treinamento', Icons.fitness_center_outlined),
  track('TRACK', 'Trilha', Icons.route_outlined),
  workshop('WORKSHOP', 'Oficina', Icons.handyman_outlined);

  const TrainingKind(this.apiValue, this.label, this.icon);

  final String apiValue;
  final String label;
  final IconData icon;

  static TrainingKind fromApi(String? value) =>
      TrainingKind.values.firstWhere((k) => k.apiValue == value, orElse: () => TrainingKind.course);
}

/// Situacao da matricula (EnrollmentStatus da API).
enum EnrollmentStatus {
  enrolled('ENROLLED', 'Matriculado', AppColors.neutral),
  inProgress('IN_PROGRESS', 'Em andamento', AppColors.accent),
  completed('COMPLETED', 'Concluído', AppColors.success),
  dropped('DROPPED', 'Abandonado', AppColors.neutral),
  expired('EXPIRED', 'Prazo encerrado', AppColors.alert);

  const EnrollmentStatus(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  static EnrollmentStatus fromApi(String? value) => EnrollmentStatus.values.firstWhere(
    (s) => s.apiValue == value,
    orElse: () => EnrollmentStatus.enrolled,
  );
}

/// Formacao do catalogo (`GET /training/catalog`).
class Training {
  const Training({
    required this.id,
    required this.code,
    required this.title,
    required this.kind,
    required this.isMandatory,
    this.summary,
    this.description,
    this.workloadMinutes,
    this.language,
    this.availableTo,
    this.myEnrollment,
  });

  factory Training.fromJson(Map<String, dynamic> json) => Training(
    id: json['id'] as String,
    code: json['code'] as String? ?? '',
    title: json['title'] as String? ?? '',
    kind: TrainingKind.fromApi(json['kind'] as String?),
    isMandatory: json['isMandatory'] == true,
    summary: json['summary'] as String?,
    description: json['description'] as String?,
    workloadMinutes: (json['workloadMinutes'] as num?)?.toInt(),
    language: json['language'] as String?,
    availableTo: json['availableTo'] is String
        ? DateTime.tryParse(json['availableTo'] as String)
        : null,
    myEnrollment: _enrollmentOf(json['enrollment'] ?? json['enrollments']),
  );

  /// A API devolve a matricula do proprio usuario em `enrollment`
  /// (objeto quando ha uma, lista em respostas antigas).
  static TrainingEnrollment? _enrollmentOf(Object? value) => switch (value) {
    final Map<String, dynamic> map => TrainingEnrollment.fromJson(map),
    final List list when list.isNotEmpty =>
      TrainingEnrollment.fromJson((list.first as Map).cast<String, dynamic>()),
    _ => null,
  };

  final String id;
  final String code;
  final String title;
  final TrainingKind kind;
  final bool isMandatory;
  final String? summary;
  final String? description;
  final int? workloadMinutes;
  final String? language;
  final DateTime? availableTo;
  final TrainingEnrollment? myEnrollment;

  bool get isEnrolled => myEnrollment != null;

  /// Carga horária em fato: "3h45" ou "45 min".
  String get workloadText {
    final minutes = workloadMinutes;
    if (minutes == null || minutes == 0) return 'Carga horária não informada';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h${rest.toString().padLeft(2, '0')}';
  }
}

/// Matricula de um pastor em uma formacao (`GET /training/enrollments`).
class TrainingEnrollment {
  const TrainingEnrollment({
    required this.id,
    required this.status,
    required this.progressPct,
    this.trainingId,
    this.trainingTitle,
    this.pastorId,
    this.pastoralName,
    this.enrolledAt,
    this.startedAt,
    this.completedAt,
    this.dueAt,
    this.score,
  });

  factory TrainingEnrollment.fromJson(Map<String, dynamic> json) {
    final training = (json['training'] as Map?)?.cast<String, dynamic>();
    final pastor = (json['pastor'] as Map?)?.cast<String, dynamic>();
    return TrainingEnrollment(
      // Respostas resumidas podem vir sem id; so o detalhe precisa dele.
      id: json['id'] as String? ?? '',
      status: EnrollmentStatus.fromApi(json['status'] as String?),
      progressPct: (json['progressPct'] as num?)?.toInt() ?? 0,
      trainingId: json['trainingId'] as String?,
      trainingTitle: training?['title'] as String?,
      pastorId: json['pastorId'] as String?,
      pastoralName: pastor?['pastoralName'] as String?,
      enrolledAt: _date(json['enrolledAt']),
      startedAt: _date(json['startedAt']),
      completedAt: _date(json['completedAt']),
      dueAt: _date(json['dueAt']),
      score: (json['score'] as num?)?.toInt(),
    );
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  final String id;
  final EnrollmentStatus status;
  final int progressPct;
  final String? trainingId;
  final String? trainingTitle;
  final String? pastorId;
  final String? pastoralName;
  final DateTime? enrolledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? dueAt;
  final int? score;

  bool get isCompleted => status == EnrollmentStatus.completed;

  /// Dias até o prazo, quando existe prazo. Fato, sem julgamento.
  int? get daysUntilDue {
    final due = dueAt;
    if (due == null) return null;
    return due.difference(DateTime.now()).inDays;
  }
}

/// Modulo de uma formacao.
class TrainingModule {
  const TrainingModule({
    required this.id,
    required this.title,
    required this.contentType,
    required this.isRequired,
    this.description,
    this.contentUrl,
    this.contentBody,
    this.durationMinutes,
    this.completed = false,
  });

  factory TrainingModule.fromJson(Map<String, dynamic> json) => TrainingModule(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    contentType: json['contentType'] as String? ?? 'TEXT',
    isRequired: json['isRequired'] != false,
    description: json['description'] as String?,
    contentUrl: json['contentUrl'] as String?,
    contentBody: json['contentBody'] as String?,
    durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
  );

  final String id;
  final String title;
  final String contentType;
  final bool isRequired;
  final String? description;
  final String? contentUrl;
  final String? contentBody;
  final int? durationMinutes;
  final bool completed;

  IconData get icon => switch (contentType.toUpperCase()) {
    'VIDEO' => Icons.play_circle_outline_rounded,
    'PDF' || 'DOCUMENT' => Icons.picture_as_pdf_outlined,
    'QUIZ' => Icons.quiz_outlined,
    'LINK' => Icons.link_rounded,
    _ => Icons.article_outlined,
  };

  TrainingModule copyWith({bool? completed}) => TrainingModule(
    id: id,
    title: title,
    contentType: contentType,
    isRequired: isRequired,
    description: description,
    contentUrl: contentUrl,
    contentBody: contentBody,
    durationMinutes: durationMinutes,
    completed: completed ?? this.completed,
  );
}

/// Formacao detalhada (`GET /training/:id`): conteudo + minha matricula.
class TrainingDetail {
  const TrainingDetail({
    required this.training,
    required this.modules,
    this.completedModuleIds = const {},
  });

  factory TrainingDetail.fromJson(Map<String, dynamic> json) {
    final done = <String>{};
    final raw = json['enrollment'] ?? json['enrollments'];
    final progress = raw is Map ? raw['progress'] : null;
    if (progress is List) {
      for (final item in progress.cast<Map<String, dynamic>>()) {
        if (item['completed'] == true && item['moduleId'] is String) {
          done.add(item['moduleId'] as String);
        }
      }
    }
    return TrainingDetail(
      training: Training.fromJson(json),
      modules: (json['modules'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(TrainingModule.fromJson)
          .map((m) => m.copyWith(completed: done.contains(m.id)))
          .toList(),
      completedModuleIds: done,
    );
  }

  final Training training;
  final List<TrainingModule> modules;
  final Set<String> completedModuleIds;

  TrainingEnrollment? get myEnrollment => training.myEnrollment;
  bool get isEnrolled => myEnrollment != null;
}
