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
/// specialty/specialties it involves, and a short reason why. This is
/// the terminal output of Phase 3.1 Part 1A: nothing consumes it to
/// actually call another agent yet (that's a later part).
class TaskClassificationEntity extends Equatable {
  final List<TaskCategory> categories;
  final String reason;

  const TaskClassificationEntity({
    required this.categories,
    required this.reason,
  });

  @override
  List<Object?> get props => [categories, reason];
}
