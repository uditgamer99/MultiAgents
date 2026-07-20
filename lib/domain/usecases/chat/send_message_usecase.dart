import '../../entities/chat_message_entity.dart';
import '../../repositories/chat_repository.dart';
import '../../services/agent_response_service.dart';

/// Orchestrates one send: persist the user's message, ask the
/// (currently fake) response service for a reply, then persist that
/// reply too. Swapping [AgentResponseService]'s implementation later
/// changes nothing here.
class SendMessageUseCase {
  final ChatRepository _repository;
  final AgentResponseService _responseService;

  SendMessageUseCase(this._repository, this._responseService);

  Future<void> call({
    required String agentId,
    required String text,
  }) async {
    final userMessage = ChatMessageEntity(
      id: '',
      agentId: agentId,
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );
    await _repository.addMessage(userMessage);

    final replyText = await _responseService.getResponse(
      agentId: agentId,
      userMessage: text,
    );

    final agentMessage = ChatMessageEntity(
      id: '',
      agentId: agentId,
      text: replyText,
      sender: MessageSender.agent,
      timestamp: DateTime.now(),
    );
    await _repository.addMessage(agentMessage);
  }
}
