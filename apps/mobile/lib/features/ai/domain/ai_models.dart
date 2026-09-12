class CopilotSuggestion {
  const CopilotSuggestion({
    required this.title,
    required this.description,
    required this.priority,
    required this.actionLabel,
    required this.actionPath,
  });

  factory CopilotSuggestion.fromJson(Map<String, dynamic> json) =>
      CopilotSuggestion(
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        priority: json['priority'] as String? ?? 'média',
        actionLabel: json['actionLabel'] as String? ?? 'Abrir',
        actionPath: json['actionPath'] as String? ?? '/dashboard',
      );

  final String title;
  final String description;
  final String priority;
  final String actionLabel;
  final String actionPath;
}

class CopilotResult {
  const CopilotResult({
    required this.role,
    required this.source,
    required this.enabled,
    required this.summary,
    required this.suggestions,
    required this.disclaimer,
    this.model,
  });

  factory CopilotResult.fromJson(Map<String, dynamic> json) => CopilotResult(
    role: json['role'] as String? ?? 'pastor',
    source: json['source'] as String? ?? 'local',
    enabled: json['enabled'] as bool? ?? false,
    model: json['model'] as String?,
    summary: json['summary'] as String? ?? '',
    suggestions: (json['suggestions'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CopilotSuggestion.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false),
    disclaimer: json['disclaimer'] as String? ?? '',
  );

  final String role;
  final String source;
  final bool enabled;
  final String? model;
  final String summary;
  final List<CopilotSuggestion> suggestions;
  final String disclaimer;

  bool get fromNvidia => source == 'nvidia-nim';
}

class AiIntentResult {
  const AiIntentResult({
    required this.reply,
    required this.actionPath,
    required this.source,
    this.model,
  });

  factory AiIntentResult.fromJson(Map<String, dynamic> json) => AiIntentResult(
    reply: json['reply'] as String? ?? 'Não consegui interpretar esse pedido.',
    actionPath: json['actionPath'] as String?,
    source: json['source'] as String? ?? 'local',
    model: json['model'] as String?,
  );

  final String reply;
  final String? actionPath;
  final String source;
  final String? model;
}
