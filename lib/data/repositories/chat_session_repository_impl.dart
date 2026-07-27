import '../../domain/entities/chat_session_entity.dart';
import '../../domain/repositories/chat_session_repository.dart';
import '../datasources/chat_session_local_datasource.dart';
import '../models/chat_session_model.dart';

class ChatSessionRepositoryImpl implements ChatSessionRepository {
  final ChatSessionLocalDataSource _localDataSource;

  ChatSessionRepositoryImpl({ChatSessionLocalDataSource? localDataSource})
      : _localDataSource = localDataSource ?? ChatSessionLocalDataSource();

  @override
  Future<List<ChatSessionEntity>> getAllSessions() async {
    final all = await _localDataSource.getAll();
    return all.values.toList();
  }

  @override
  Future<ChatSessionEntity?> getSession(String agentId) async {
    final all = await _localDataSource.getAll();
    return all[agentId];
  }

  @override
  Future<void> saveSession(ChatSessionEntity session) async {
    final all = await _localDataSource.getAll();
    all[session.agentId] = ChatSessionModel.fromEntity(session);
    await _localDataSource.saveAll(all);
  }

  @override
  Future<void> renameSession(String agentId, String title) async {
    final all = await _localDataSource.getAll();
    final existing = all[agentId];
    if (existing == null) return;
    all[agentId] = ChatSessionModel.fromEntity(
      existing.copyWith(title: title, updatedAt: existing.updatedAt),
    );
    await _localDataSource.saveAll(all);
  }

  @override
  Future<void> setPinned(String agentId, bool isPinned) async {
    final all = await _localDataSource.getAll();
    final existing = all[agentId];
    if (existing == null) return;
    all[agentId] = ChatSessionModel.fromEntity(
      existing.copyWith(isPinned: isPinned),
    );
    await _localDataSource.saveAll(all);
  }

  @override
  Future<void> touchSession(String agentId) async {
    final all = await _localDataSource.getAll();
    final existing = all[agentId];
    final now = DateTime.now();
    if (existing == null) {
      all[agentId] = ChatSessionModel(
        agentId: agentId,
        title: ChatSessionEntity.defaultTitle,
        isPinned: false,
        createdAt: now,
        updatedAt: now,
      );
    } else {
      all[agentId] = ChatSessionModel.fromEntity(
        existing.copyWith(updatedAt: now),
      );
    }
    await _localDataSource.saveAll(all);
  }

  @override
  Future<void> deleteSession(String agentId) async {
    final all = await _localDataSource.getAll();
    all.remove(agentId);
    await _localDataSource.saveAll(all);
  }
}
