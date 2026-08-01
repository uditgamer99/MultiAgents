import 'dart:async';

import '../../../core/errors/exceptions.dart';
import '../../../core/utils/cancel_token.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/send_stage.dart';
import '../../entities/chat_attachment_entity.dart';
import '../../entities/chat_message_entity.dart';
import '../../repositories/chat_repository.dart';
import '../../services/agent_response_service.dart';
import '../../services/attachment_context_service.dart';

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
///
/// [cancelToken] (if provided and cancelled) is checked at three
/// points — before requesting a reply, and again right after one
/// arrives — so a stopped generation can never end up silently saved
/// to the conversation after the user asked it to stop. The user's
/// own message is never affected by cancellation: it's already saved
/// before any of this cancellation logic even applies.
class SendMessageUseCase {
  static const _writeTimeout = Duration(seconds: 12);
  static const _readTimeout = Duration(seconds: 12);
  static const _responseTimeout = Duration(seconds: 20);
  static const _attachmentTimeout = Duration(seconds: 15);

  final ChatRepository _repository;
  final AgentResponseService _responseService;
  final AttachmentContextService _attachmentContextService;

  SendMessageUseCase(
    this._repository,
    this._responseService,
    this._attachmentContextService,
  );

  Future<void> call({
    required String agentId,
    required String text,
    List<ChatAttachmentEntity> attachments = const [],
    CancelToken? cancelToken,
    void Function(SendStage stage)? onStage,
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
      // The stored message keeps attachment metadata only (path,
      // name, size) — the actual file contents are read separately
      // below, just for this request, and are never persisted here.
      attachments: attachments,
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

    if (cancelToken != null && cancelToken.isCancelled) {
      // Stopped right after sending — the user's message above is
      // already saved (correct), we just never ask for a reply.
      return;
    }

    // Read/extract every attachment and format it into the labeled
    // context block the agent receives alongside the user's text.
    // Failing to build context is never fatal to the send — a
    // timeout or an unexpected error here just means the message
    // goes out without attachment context, same as if none had been
    // attached.
    String? attachmentContext;
    try {
      final contextResult = await _attachmentContextService
          .build(attachments, onStage: onStage)
          .timeout(_attachmentTimeout);
      attachmentContext = contextResult.contextText;
    } catch (error, stackTrace) {
      AppLogger.error(
        'SendMessageUseCase: failed to build attachment context for '
        '$agentId, continuing without it',
        error,
        stackTrace,
      );
    }

    if (cancelToken != null && cancelToken.isCancelled) {
      return;
    }

    onStage?.call(SendStage.sendingToAi);

    // A message with attachments but no typed caption still needs
    // something for the agent to act on — the user's own (possibly
    // empty) text is still what gets saved to the conversation above.
    final effectiveUserMessage = text.isEmpty && attachments.isNotEmpty
        ? 'Please review the attached file(s) and respond accordingly.'
        : text;

    String replyText;
    try {
      replyText = await _responseService
          .getResponse(
            agentId: agentId,
            history: history,
            userMessage: effectiveUserMessage,
            attachmentContext: attachmentContext,
            cancelToken: cancelToken,
          )
          .timeout(_responseTimeout);
    } catch (error, stackTrace) {
      if (error is OperationCancelledException) {
        // A deliberate stop, not a failure — nothing to log, nothing
        // to show as an error.
        return;
      }
      AppLogger.error(
        'SendMessageUseCase: agent response failed for $agentId'
        '${error is AgentResponseException ? ' (${error.technicalDetail})' : ''}',
        error,
        stackTrace,
      );
      // AgentResponseException already carries a short, user-safe
      // message distinguishing network vs API-error causes; a plain
      // timeout gets its own message; anything else falls back to a
      // generic one.
      final friendlyMessage = switch (error) {
        AgentResponseException(:final message) => message,
        TimeoutException() =>
          'The request took too long. Please try again.',
        _ => "Sorry, I couldn't generate a response. Please try again.",
      };
      await _addErrorMessage(agentId, friendlyMessage);
      rethrow;
    }

    if (cancelToken != null && cancelToken.isCancelled) {
      // A reply arrived but the user stopped in the meantime — discard
      // it rather than appending something they no longer asked for.
      return;
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
