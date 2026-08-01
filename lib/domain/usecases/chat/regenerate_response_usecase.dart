import 'dart:async';

import '../../../core/utils/cancel_token.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/send_stage.dart';
import '../../entities/chat_message_entity.dart';
import '../../repositories/chat_repository.dart';
import '../../services/agent_response_service.dart';
import '../../services/attachment_context_service.dart';

/// Regenerates one AI reply: asks the response service for a brand
/// new answer to the same preceding user message — including any
/// attachments it had, re-processed the same way a fresh send would
/// be, so regenerating a reply to "analyze this PDF" doesn't lose the
/// PDF — then overwrites that exact message in place. Never touches
/// the user's message — it is never re-sent or duplicated, only read.
///
/// On failure, the old reply is left completely untouched — a failed
/// regeneration should never destroy a working response. The same is
/// true if [cancelToken] is cancelled mid-flight: the old reply stays
/// exactly as it was.
class RegenerateResponseUseCase {
  static const _responseTimeout = Duration(seconds: 20);
  static const _attachmentTimeout = Duration(seconds: 15);

  final ChatRepository _repository;
  final AgentResponseService _responseService;
  final AttachmentContextService _attachmentContextService;

  RegenerateResponseUseCase(
    this._repository,
    this._responseService,
    this._attachmentContextService,
  );

  Future<void> call({
    required ChatMessageEntity aiMessage,
    required ChatMessageEntity precedingUserMessage,
    required List<ChatMessageEntity> historyBeforeUserMessage,
    CancelToken? cancelToken,
    void Function(SendStage stage)? onStage,
  }) async {
    String? attachmentContext;
    try {
      final contextResult = await _attachmentContextService
          .build(precedingUserMessage.attachments, onStage: onStage)
          .timeout(_attachmentTimeout);
      attachmentContext = contextResult.contextText;
    } catch (error, stackTrace) {
      AppLogger.error(
        'RegenerateResponseUseCase: failed to build attachment context '
        'for ${aiMessage.agentId}, continuing without it',
        error,
        stackTrace,
      );
    }

    if (cancelToken != null && cancelToken.isCancelled) {
      return;
    }

    onStage?.call(SendStage.sendingToAi);

    final effectiveUserMessage =
        precedingUserMessage.text.isEmpty &&
            precedingUserMessage.attachments.isNotEmpty
        ? 'Please review the attached file(s) and respond accordingly.'
        : precedingUserMessage.text;

    final replyText = await _responseService
        .getResponse(
          agentId: aiMessage.agentId,
          history: historyBeforeUserMessage,
          userMessage: effectiveUserMessage,
          attachmentContext: attachmentContext,
          cancelToken: cancelToken,
        )
        .timeout(_responseTimeout);

    if (cancelToken != null && cancelToken.isCancelled) {
      // Stopped before the regenerated reply could be saved — leave
      // the original message untouched.
      return;
    }

    final updatedMessage = ChatMessageEntity(
      id: aiMessage.id,
      agentId: aiMessage.agentId,
      text: replyText,
      sender: MessageSender.agent,
      timestamp: aiMessage.timestamp,
    );

    await _repository.updateMessage(updatedMessage);
  }
}
