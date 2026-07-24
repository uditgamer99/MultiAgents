import '../entities/chat_message_entity.dart';

/// Abstraction over "however the agent generates a reply". Phase 4
/// implemented this with fake canned responses; [GroqService] now
/// implements it with real Groq API calls — the ViewModel, screens,
/// and usecases never had to change either time.
abstract class AgentResponseService {
  /// [history] is the conversation so far (oldest first), NOT
  /// including [userMessage] — implementations are expected to send
  /// the agent's system prompt, then [history], then [userMessage] as
  /// the full conversation context for each request.
  Future<String> getResponse({
    required String agentId,
    required List<ChatMessageEntity> history,
    required String userMessage,
  });
}
