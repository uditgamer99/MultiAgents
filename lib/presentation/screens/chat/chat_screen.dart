import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/send_stage.dart';
import '../../../domain/entities/agent_entity.dart';
import '../../../domain/entities/chat_message_entity.dart';
import '../../providers/agent_list_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/chat_session_provider.dart';
import 'widgets/chat_input_field.dart';
import 'widgets/message_bubble.dart';
import 'widgets/typing_indicator.dart';

/// Reusable chat UI shared by every agent. [agentId] is the only
/// thing that changes between agents — it selects the Firestore
/// history and (for now) the fake canned response.
class ChatScreen extends ConsumerStatefulWidget {
  final String agentId;

  const ChatScreen({super.key, required this.agentId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  /// Tracks message count so the chat-session "last updated" timestamp
  /// only gets touched when a message is genuinely *new* — not on
  /// every rebuild or on the initial load of existing history.
  int? _lastMessageCount;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String? _labelForStage(SendStage? stage) {
    switch (stage) {
      case SendStage.readingAttachments:
        return 'Reading attachment…';
      case SendStage.extractingText:
        return 'Extracting text…';
      case SendStage.preparingContext:
        return 'Preparing context…';
      case SendStage.sendingToAi:
        return 'Sending to AI…';
      case null:
        return null;
    }
  }

  AgentEntity? _findAgent(List<AgentEntity> agents) {
    for (final agent in agents) {
      if (agent.id == widget.agentId) return agent;
    }
    return null;
  }

  /// Walks backward from [aiMessageIndex] to find the nearest
  /// preceding user message. Doesn't assume strict user/agent
  /// alternation (e.g. an inserted error message could sit between
  /// two agent-sender messages), so this is a search, not `index - 1`.
  int? _precedingUserMessageIndex(
    List<ChatMessageEntity> messages,
    int aiMessageIndex,
  ) {
    for (var i = aiMessageIndex - 1; i >= 0; i--) {
      if (messages[i].sender == MessageSender.user) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.agentId));
    final sendState = ref.watch(chatViewModelProvider(widget.agentId));
    final isSending = sendState.isLoading;
    final chatNotifier = ref.read(chatViewModelProvider(widget.agentId).notifier);
    final regeneratingMessageId = chatNotifier.regeneratingMessageId;
    final agents = ref.watch(agentListProvider).valueOrNull ?? const [];
    final agent = _findAgent(agents);

    // Auto-scroll whenever the message list updates or a send starts.
    // Also bumps the chat session's "last updated" metadata (for the
    // Chats list's sorting) — but only when a message was genuinely
    // added, not on the initial load of existing history.
    ref.listen(chatMessagesProvider(widget.agentId), (previous, next) {
      next.whenData((messages) {
        _scrollToBottom();
        final previousCount = _lastMessageCount;
        _lastMessageCount = messages.length;
        if (previousCount != null && messages.length > previousCount) {
          ref.read(chatSessionsProvider.notifier).touch(widget.agentId);
        }
      });
    });
    ref.listen(chatViewModelProvider(widget.agentId), (previous, next) {
      if (next.isLoading) _scrollToBottom();
      next.whenOrNull(
        error: (error, _) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(error.toString())));
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(agent != null ? '${agent.icon}  ${agent.name}' : 'Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text("Couldn't load chat: $error")),
              data: (messages) {
                if (messages.isEmpty && !isSending) {
                  return Center(
                    child: Text(
                      'Say hello to get started',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length + (isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return ValueListenableBuilder<SendStage?>(
                        valueListenable: chatNotifier.stageNotifier,
                        builder: (context, stage, _) {
                          return TypingIndicator(
                            label: _labelForStage(stage),
                          );
                        },
                      );
                    }

                    final message = messages[index];
                    final isAgentMessage =
                        message.sender == MessageSender.agent;
                    final precedingUserIndex = isAgentMessage
                        ? _precedingUserMessageIndex(messages, index)
                        : null;

                    if (!isAgentMessage || precedingUserIndex == null) {
                      return MessageBubble(message: message);
                    }

                    final precedingUserMessage =
                        messages[precedingUserIndex];
                    final historyBeforeUserMessage =
                        messages.sublist(0, precedingUserIndex);

                    return MessageBubble(
                      message: message,
                      showRegenerate: true,
                      isRegenerating: regeneratingMessageId == message.id,
                      regenerateEnabled: !isSending,
                      onRegenerate: () {
                        ref
                            .read(
                              chatViewModelProvider(widget.agentId).notifier,
                            )
                            .regenerate(
                              aiMessage: message,
                              precedingUserMessage: precedingUserMessage,
                              historyBeforeUserMessage:
                                  historyBeforeUserMessage,
                            );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          ChatInputField(
            isGenerating: isSending,
            onSend: (text, attachments) {
              ref
                  .read(chatViewModelProvider(widget.agentId).notifier)
                  .sendMessage(text, attachments: attachments);
            },
            onStop: () {
              ref
                  .read(chatViewModelProvider(widget.agentId).notifier)
                  .cancelCurrent();
            },
          ),
        ],
      ),
    );
  }
}
