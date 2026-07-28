import '../../core/utils/cancel_token.dart';
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
  ///
  /// [cancelToken], if provided and cancelled mid-request, should
  /// cause this to throw [OperationCancelledException] (see
  /// core/errors/exceptions.dart) rather than a network/API error.
  Future<String> getResponse({
    required String agentId,
    required List<ChatMessageEntity> history,
    required String userMessage,
    CancelToken? cancelToken,
  });
}
