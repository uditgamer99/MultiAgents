import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/exceptions.dart';
import '../../core/utils/cancel_token.dart';
import '../../core/utils/send_stage.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/services/attachment_context_builder.dart';
import '../../data/services/groq_service.dart';
import '../../domain/entities/chat_attachment_entity.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/services/agent_response_service.dart';
import '../../domain/services/attachment_context_service.dart';
import '../../domain/usecases/chat/get_messages_usecase.dart';
import '../../domain/usecases/chat/regenerate_response_usecase.dart';
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

/// Turns attachments into the Groq-ready context block (Part 8B.2).
/// Swapping this later — e.g. to add caching — only means changing
/// this one line, the same way [agentResponseServiceProvider] works.
final attachmentContextServiceProvider =
    Provider<AttachmentContextService>((ref) {
  return AttachmentContextBuilder();
});

final getMessagesUseCaseProvider = Provider<GetMessagesUseCase>((ref) {
  return GetMessagesUseCase(ref.watch(chatRepositoryProvider));
});

final sendMessageUseCaseProvider = Provider<SendMessageUseCase>((ref) {
  return SendMessageUseCase(
    ref.watch(chatRepositoryProvider),
    ref.watch(agentResponseServiceProvider),
    ref.watch(attachmentContextServiceProvider),
  );
});

final regenerateResponseUseCaseProvider =
    Provider<RegenerateResponseUseCase>((ref) {
  return RegenerateResponseUseCase(
    ref.watch(chatRepositoryProvider),
    ref.watch(agentResponseServiceProvider),
    ref.watch(attachmentContextServiceProvider),
  );
});

/// Per-agent live message stream — each agent's Firestore history is
/// independent, keyed by agentId via `.family`.
final chatMessagesProvider =
    StreamProvider.family<List<ChatMessageEntity>, String>((ref, agentId) {
  return ref.watch(getMessagesUseCaseProvider)(agentId);
});

/// Per-agent ViewModel. Only tracks transient send/regenerate state
/// (idle/loading/error) — the message list itself lives in
/// [chatMessagesProvider] since Firestore is the source of truth.
/// `state.isLoading` doubles as the typing-indicator flag, swaps the
/// Send button for a Stop button, and disables every regenerate
/// button while true, so a normal send and a regenerate (or two
/// regenerates) can never overlap.
class ChatViewModel extends StateNotifier<AsyncValue<void>> {
  final SendMessageUseCase _sendMessageUseCase;
  final RegenerateResponseUseCase _regenerateResponseUseCase;
  final String agentId;

  /// Id of the specific message currently being regenerated, if any —
  /// lets the UI show a spinner on just that one message's button
  /// while every other button is simply disabled.
  String? _regeneratingMessageId;
  String? get regeneratingMessageId => _regeneratingMessageId;

  /// Cancel token for whichever request (send or regenerate) is
  /// currently in flight, if any — Stop cancels whichever one it is.
  /// Null whenever nothing is running.
  CancelToken? _currentCancelToken;

  /// Which real step of the current send/regenerate is running right
  /// now (reading attachments, extracting text, preparing context,
  /// sending to the AI) — null whenever nothing is in flight. A
  /// plain [ValueNotifier] rather than part of [state] so the UI can
  /// watch it independently without extra rebuild plumbing.
  final ValueNotifier<SendStage?> stageNotifier = ValueNotifier<SendStage?>(
    null,
  );

  ChatViewModel(
    this._sendMessageUseCase,
    this._regenerateResponseUseCase,
    this.agentId,
  ) : super(const AsyncData(null));

  Future<void> sendMessage(
    String text, {
    List<ChatAttachmentEntity> attachments = const [],
  }) async {
    final trimmed = text.trim();
    // A message needs either text or at least one attachment — an
    // empty send with nothing attached is still a no-op.
    if (trimmed.isEmpty && attachments.isEmpty) return;
    if (state.isLoading) return;

    final cancelToken = CancelToken();
    _currentCancelToken = cancelToken;
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() {
      return _sendMessageUseCase(
        agentId: agentId,
        text: trimmed,
        attachments: attachments,
        cancelToken: cancelToken,
        onStage: (stage) => stageNotifier.value = stage,
      );
    });

    // Cleared before the final state assignment below, so that by the
    // time listeners rebuild in response to it, everything already
    // reads back correctly (no in-between frame where a Stop button
    // is shown with nothing left to stop).
    stageNotifier.value = null;
    _currentCancelToken = null;
    state = _isCancelled(result) ? const AsyncData(null) : result;
  }

  Future<void> regenerate({
    required ChatMessageEntity aiMessage,
    required ChatMessageEntity precedingUserMessage,
    required List<ChatMessageEntity> historyBeforeUserMessage,
  }) async {
    if (state.isLoading) return;

    final cancelToken = CancelToken();
    _currentCancelToken = cancelToken;
    _regeneratingMessageId = aiMessage.id;
    state = const AsyncLoading();

    final result = await AsyncValue.guard(() {
      return _regenerateResponseUseCase(
        aiMessage: aiMessage,
        precedingUserMessage: precedingUserMessage,
        historyBeforeUserMessage: historyBeforeUserMessage,
        cancelToken: cancelToken,
        onStage: (stage) => stageNotifier.value = stage,
      );
    });

    stageNotifier.value = null;
    _regeneratingMessageId = null;
    _currentCancelToken = null;
    state = _isCancelled(result) ? const AsyncData(null) : result;
  }

  /// Cancels whichever request (send or regenerate) is currently in
  /// flight. Safe to call when nothing is running — becomes a no-op.
  void cancelCurrent() {
    _currentCancelToken?.cancel();
  }

  bool _isCancelled(AsyncValue<void> value) {
    return value.hasError && value.error is OperationCancelledException;
  }

  @override
  void dispose() {
    stageNotifier.dispose();
    super.dispose();
  }
}

final chatViewModelProvider =
    StateNotifierProvider.family<ChatViewModel, AsyncValue<void>, String>(
        (ref, agentId) {
  return ChatViewModel(
    ref.watch(sendMessageUseCaseProvider),
    ref.watch(regenerateResponseUseCaseProvider),
    agentId,
  );
});
