import '../../entities/chat_message_entity.dart';
import '../../repositories/chat_repository.dart';

class GetMessagesUseCase {
  final ChatRepository _repository;

  GetMessagesUseCase(this._repository);

  Stream<List<ChatMessageEntity>> call(String agentId) {
    return _repository.watchMessages(agentId);
  }
}
