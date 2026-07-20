import '../../domain/entities/agent_entity.dart';

/// Data-layer AgentModel. Currently backed by a local static list;
/// the `fromJson` factory is here so swapping the datasource for
/// Firestore later is a datasource-only change — nothing above this
/// layer needs to know where the data came from.
class AgentModel extends AgentEntity {
  const AgentModel({
    required super.id,
    required super.icon,
    required super.name,
    required super.description,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      id: json['id'] as String,
      icon: json['icon'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
    );
  }
}
