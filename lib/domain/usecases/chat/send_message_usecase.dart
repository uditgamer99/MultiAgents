import '../../../core/utils/logger.dart';
import '../../entities/chat_message_entity.dart';
import '../../repositories/chat_repository.dart';
import '../../services/agent_response_service.dart';

/// Orchestrates one send: load prior conversation history, persist the
/// user's message, ask the response service for a reply (passing that
/// history along so the agent has memory of the conversation), then
/// persist the reply too. Swapping [AgentResponseService]'s
/// implementation changes nothing here.
///
/// Every network-bound step below is wrapped with a timeout so a
/// stalled Firestore call or a hung AI call can never leave the chat
/// screen's typing indicator spinning forever — the Future backing it
/// is now guaranteed to either complete or throw within a bounded
/// time, and [ChatViewModel.sendMessage] (via `AsyncValue.guard`)
/// always clears its loading state once that happens, in both the
/// success and the failure path.
class SendMessageUseCase {
  static const _writeTimeout = Duration(seconds: 12);
  static const _readTimeout = Duration(seconds: 12);
  static const _responseTimeout = Duration(seconds: 20);

  final ChatRepository _repository;
  final AgentResponseService _responseService;

  SendMessageUseCase(this._repository, this._responseService);

  Future<void> call({
    required String agentId,
    required String text,
  }) async {
    // Snapshot the conversation as it stood *before* this message —
    // this becomes the "previous user/assistant messages" context
    // sent to the agent. Failing to load history isn't fatal: fall
    // back to an empty history rather than blocking the send.
    List<ChatMessageEntity> history = const [];
    try {
      history = await _repository.getMessages(agentId).timeout(_readTimeout);
    } catch (error, stackTrace) {
      AppLogger.error(
        'SendMessageUseCase: failed to load history for $agentId, '
        'continuing without conversation context',
        error,
        stackTrace,
      );
    }

    final userMessage = ChatMessageEntity(
      id: '',
      agentId: agentId,
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    try {
      await _repository.addMessage(userMessage).timeout(_writeTimeout);
    } catch (error, stackTrace) {
      AppLogger.error(
        'SendMessageUseCase: failed to save user message for $agentId',
        error,
        stackTrace,
      );
      await _addErrorMessage(
        agentId,
        "Couldn't send your message. Please check your connection and try again.",
      );
      rethrow;
    }

    String replyText;
    try {
      replyText = await _responseService
          .getResponse(agentId: agentId, history: history, userMessage: text)
          .timeout(_responseTimeout);
    } catch (error, stackTrace) {
      AppLogger.error(
        'SendMessageUseCase: agent response failed for $agentId',
        error,
        stackTrace,
      );
      await _addErrorMessage(
        agentId,
        "Sorry, I couldn't generate a response. Please try again.",
      );
      rethrow;
    }

    final agentMessage = ChatMessageEntity(
      id: '',
      agentId: agentId,
      text: replyText,
      sender: MessageSender.agent,
      timestamp: DateTime.now(),
    );

    try {
      await _repository.addMessage(agentMessage).timeout(_writeTimeout);
    } catch (error, stackTrace) {
      AppLogger.error(
        'SendMessageUseCase: failed to save agent reply for $agentId',
        error,
        stackTrace,
      );
      // The reply was generated but couldn't be saved — still tell the
      // user, so they aren't left staring at a stuck typing indicator
      // with no explanation.
      await _addErrorMessage(
        agentId,
        "Got a response but couldn't save it. Please try again.",
      );
      rethrow;
    }
  }

  /// Best-effort: writes a visible agent-side message describing the
  /// failure, so the user sees *something* in the chat instead of only
  /// a snackbar (or nothing, if the failure happened before this
  /// existed). Failures here are logged but swallowed — we don't want
  /// a broken error-reporting write to mask the original error.
  Future<void> _addErrorMessage(String agentId, String message) async {
    try {
      await _repository.addMessage(
        ChatMessageEntity(
          id: '',
          agentId: agentId,
          text: message,
          sender: MessageSender.agent,
          timestamp: DateTime.now(),
        ),
      ).timeout(_writeTimeout);
    } catch (error, stackTrace) {
      AppLogger.error(
        'SendMessageUseCase: failed to write error message for $agentId',
        error,
        stackTrace,
      );
    }
  }
}
