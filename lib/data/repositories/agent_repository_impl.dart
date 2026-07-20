import '../../domain/entities/agent_entity.dart';
import '../../domain/repositories/agent_repository.dart';
import '../datasources/agent_local_datasource.dart';

/// Concrete [AgentRepository] backed by [AgentLocalDataSource].
/// Swap the datasource here for a Firestore-backed one later without
/// touching any provider or screen.
class AgentRepositoryImpl implements AgentRepository {
  final AgentLocalDataSource _localDataSource;

  AgentRepositoryImpl({AgentLocalDataSource? localDataSource})
      : _localDataSource = localDataSource ?? AgentLocalDataSource();

  @override
  Future<List<AgentEntity>> getAgents() => _localDataSource.getAgents();
}
