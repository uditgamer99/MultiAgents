import '../entities/agent_entity.dart';

/// Abstract contract for fetching agents. The Home Screen depends
/// only on this — never on the local datasource (or, later,
/// Firestore) directly.
abstract class AgentRepository {
  Future<List<AgentEntity>> getAgents();
}
