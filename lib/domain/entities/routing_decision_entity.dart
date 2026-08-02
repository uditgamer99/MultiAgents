import 'package:equatable/equatable.dart';

import 'task_classification_entity.dart';

/// A structured routing decision derived from the CEO's
/// [TaskClassificationEntity] — which existing agent(s) a request
/// would go to, if execution were implemented (it isn't yet; this is
/// Phase 3.1 Part 1B, routing decisions only, never carried out).
///
/// [selectedAgentIds] only ever contains real ids from
/// AgentLocalDataSource — built entirely from [TaskCategoryAgent],
/// never from free text the model produced, so an invented/misspelled
/// agent id is structurally impossible here.
class RoutingDecisionEntity extends Equatable {
  final List<String> selectedAgentIds;
  final String taskType;
  final String reason;
  final double? confidence;

  const RoutingDecisionEntity({
    required this.selectedAgentIds,
    required this.taskType,
    required this.reason,
    this.confidence,
  });

  /// True when the CEO couldn't confidently classify the request —
  /// per the routing rules, this means "the CEO itself handles or
  /// clarifies it", never a randomly-picked specialist.
  bool get isUnclear => selectedAgentIds.isEmpty || taskType == 'unclear';

  factory RoutingDecisionEntity.fromClassification(
    TaskClassificationEntity classification,
  ) {
    if (classification.categories.isEmpty) {
      return RoutingDecisionEntity(
        selectedAgentIds: const ['ceo'],
        taskType: 'unclear',
        reason: classification.reason,
        confidence: classification.confidence,
      );
    }

    return RoutingDecisionEntity(
      selectedAgentIds:
          classification.categories.map((c) => c.agentId).toList(),
      taskType: classification.categories.map((c) => c.name).join('+'),
      reason: classification.reason,
      confidence: classification.confidence,
    );
  }

  @override
  List<Object?> get props => [selectedAgentIds, taskType, reason, confidence];
}
