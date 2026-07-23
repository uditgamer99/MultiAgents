import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/chat_repository_impl.dart';
import '../../data/services/groq_service.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/services/agent_response_service.dart';
import '../../domain/usecases/chat/get_messages_usecase.dart';
import '../../domain/usecases/chat/send_message_usecase.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl();
});

/// Real replies via Groq's Chat Completions API. Swapping providers
/// again later (e.g. to a different model provider) only means
/// changing this one line.
final agentResponseServiceProvider = Provider<AgentResponseService>((ref) {
  return GroqService();
});

final getMessagesUseCaseProvider = Provider<GetMessagesUseCase>((ref) {
  return GetMessagesUseCase(ref.watch(chatRepositoryProvider));
});

final sendMessageUseCaseProvider = Provider<SendMessageUseCase>((ref) {
  return SendMessageUseCase(
    ref.watch(chatRepositoryProvider),
    ref.watch(agentResponseServiceProvider),
  );
});

/// Per-agent live message stream — each agent's Firestore history is
/// independent, keyed by agentId via `.family`.
final chatMessagesProvider =
    StreamProvider.family<List<ChatMessageEntity>, String>((ref, agentId) {
  return ref.watch(getMessagesUseCaseProvider)(agentId);
});

/// Per-agent ViewModel. Only tracks transient send state
/// (idle/loading/error) — the message list itself lives in
/// [chatMessagesProvider] since Firestore is the source of truth.
/// `state.isLoading` doubles as the typing-indicator flag.
class ChatViewModel extends StateNotifier<AsyncValue<void>> {
  final SendMessageUseCase _sendMessageUseCase;
  final String agentId;

  ChatViewModel(this._sendMessageUseCase, this.agentId)
      : super(const AsyncData(null));

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return _sendMessageUseCase(agentId: agentId, text: trimmed);
    });
  }
}

final chatViewModelProvider =
    StateNotifierProvider.family<ChatViewModel, AsyncValue<void>, String>(
        (ref, agentId) {
  return ChatViewModel(ref.watch(sendMessageUseCaseProvider), agentId);
});
