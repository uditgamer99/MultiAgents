import 'package:equatable/equatable.dart';

/// The specialties the CEO can classify a user's request into. Keys
/// match the task categories from the project spec exactly; each one
/// maps 1:1 to an existing specialist agent (see [TaskCategoryAgent]).
enum TaskCategory {
  research,
  design,
  webDevelopment,
  flutterDevelopment,
  aiEngineering,
  marketing,
}

extension TaskCategoryAgent on TaskCategory {
  /// The existing agent id (from AgentLocalDataSource) this category
  /// corresponds to. Not used for routing yet — that's a later
  /// phase — but keeping the mapping here now means that phase
  /// doesn't have to reinvent it.
  String get agentId {
    switch (this) {
      case TaskCategory.research:
        return 'researcher';
      case TaskCategory.design:
        return 'designer';
      case TaskCategory.webDevelopment:
        return 'web-developer';
      case TaskCategory.flutterDevelopment:
        return 'flutter-developer';
      case TaskCategory.aiEngineering:
        return 'ai-engineer';
      case TaskCategory.marketing:
        return 'marketing';
    }
  }
}

/// Result of the CEO classifying a user's request — which
/// specialty/specialties it involves, a short reason why, and
/// (optionally) how confident the model was. This is the raw parse of
/// Groq's reply; [RoutingDecisionEntity] turns it into something a
/// future execution phase could actually act on.
class TaskClassificationEntity extends Equatable {
  final List<TaskCategory> categories;
  final String reason;

  /// 0.0–1.0 if the model provided one, null otherwise — parsing
  /// never fails just because this is missing.
  final double? confidence;

  const TaskClassificationEntity({
    required this.categories,
    required this.reason,
    this.confidence,
  });

  @override
  List<Object?> get props => [categories, reason, confidence];
}
