import 'dart:async';

import '../../entities/chat_message_entity.dart';
import '../../repositories/chat_repository.dart';
import '../../services/agent_response_service.dart';

/// Regenerates one AI reply: asks the response service for a brand
/// new answer to the same preceding user message (with the same
/// earlier context it originally had), then overwrites that exact
/// message in place. Never touches the user's message — it is never
/// re-sent or duplicated, only read.
///
/// On failure, the old reply is left completely untouched — a failed
/// regeneration should never destroy a working response.
class RegenerateResponseUseCase {
  static const _responseTimeout = Duration(seconds: 20);

  final ChatRepository _repository;
  final AgentResponseService _responseService;

  RegenerateResponseUseCase(this._repository, this._responseService);

  Future<void> call({
    required ChatMessageEntity aiMessage,
    required String precedingUserMessageText,
    required List<ChatMessageEntity> historyBeforeUserMessage,
  }) async {
    final replyText = await _responseService
        .getResponse(
          agentId: aiMessage.agentId,
          history: historyBeforeUserMessage,
          userMessage: precedingUserMessageText,
        )
        .timeout(_responseTimeout);

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
