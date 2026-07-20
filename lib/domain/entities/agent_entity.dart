import 'package:equatable/equatable.dart';

/// Domain-layer representation of an AI agent card shown on the Home
/// Screen (Web Developer / Marketing / Manager, and any added later).
class AgentEntity extends Equatable {
  final String id;
  final String icon;
  final String name;
  final String description;

  const AgentEntity({
    required this.id,
    required this.icon,
    required this.name,
    required this.description,
  });

  @override
  List<Object?> get props => [id, icon, name, description];
}
