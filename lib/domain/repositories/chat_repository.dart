import '../entities/chat_message_entity.dart';

/// Abstract contract for chat persistence. The presentation layer and
/// usecases depend only on this — never on Firestore directly.
abstract class ChatRepository {
  /// Live, ordered stream of one agent's full message history — used
  /// by the chat screen's UI.
  Stream<List<ChatMessageEntity>> watchMessages(String agentId);

  /// One-time, ordered fetch of one agent's message history — used to
  /// build conversation context for an AI request, as opposed to the
  /// long-lived UI stream above.
  Future<List<ChatMessageEntity>> getMessages(String agentId);

  /// Persists a single message (user or agent) to that agent's history.
  Future<void> addMessage(ChatMessageEntity message);

  /// Deletes every message in one agent's history — used when a chat
  /// session is deleted. Does not affect any other agent's messages.
  Future<void> clearMessages(String agentId);
}
