import '../entities/chat_message_entity.dart';

/// Abstract contract for chat persistence. The presentation layer and
/// usecases depend only on this — never on Firestore directly.
abstract class ChatRepository {
  /// Live, ordered stream of one agent's full message history.
  Stream<List<ChatMessageEntity>> watchMessages(String agentId);

  /// Persists a single message (user or agent) to that agent's history.
  Future<void> addMessage(ChatMessageEntity message);
}
