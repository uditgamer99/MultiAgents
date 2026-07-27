import '../../domain/entities/chat_message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';
import '../models/chat_message_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remoteDataSource;

  ChatRepositoryImpl({ChatRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? ChatRemoteDataSource();

  @override
  Stream<List<ChatMessageEntity>> watchMessages(String agentId) {
    return _remoteDataSource.watchMessages(agentId);
  }

  @override
  Future<List<ChatMessageEntity>> getMessages(String agentId) {
    return _remoteDataSource.getMessages(agentId);
  }

  @override
  Future<void> addMessage(ChatMessageEntity message) {
    final model = ChatMessageModel(
      id: message.id,
      agentId: message.agentId,
      text: message.text,
      sender: message.sender,
      timestamp: message.timestamp,
    );
    return _remoteDataSource.addMessage(message.agentId, model);
  }

  @override
  Future<void> clearMessages(String agentId) {
    return _remoteDataSource.clearMessages(agentId);
  }
}
