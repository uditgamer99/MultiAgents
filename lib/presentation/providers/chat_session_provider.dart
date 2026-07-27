import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/chat_repository_impl.dart';
import '../../data/repositories/chat_session_repository_impl.dart';
import '../../domain/entities/chat_session_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/chat_session_repository.dart';
import 'agent_list_provider.dart';

final chatSessionRepositoryProvider = Provider<ChatSessionRepository>((ref) {
  return ChatSessionRepositoryImpl();
});

/// Reused so "Delete" can clear the agent's Firestore messages too —
/// this is the same repository/provider the Chat Screen itself uses,
/// just called from a different place.
final _chatRepositoryForSessionsProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl();
});

/// Free-text search query for the chat list, updated instantly as the
/// user types.
final chatSearchQueryProvider = StateProvider<String>((ref) => '');

/// Owns the list of chat sessions and every mutation on it (rename,
/// pin, delete). Loads lazily and keeps state in memory afterward;
/// every mutation re-persists via [ChatSessionRepository] so it
/// survives an app restart.
class ChatSessionsViewModel extends StateNotifier<AsyncValue<List<ChatSessionEntity>>> {
  final ChatSessionRepository _repository;
  final ChatRepository _chatRepository;
  final Future<List<String>> Function() _getAgentIds;

  ChatSessionsViewModel(
    this._repository,
    this._chatRepository,
    this._getAgentIds,
  ) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final agentIds = await _getAgentIds();
      final stored = await _repository.getAllSessions();
      final byId = {for (final s in stored) s.agentId: s};

      // Every known agent always has a session record — synthesize
      // (and persist) a default "New Chat" one on first sight so
      // rename/pin/etc. have something to act on immediately.
      final now = DateTime.now();
      final result = <ChatSessionEntity>[];
      for (final agentId in agentIds) {
        final existing = byId[agentId];
        if (existing != null) {
          result.add(existing);
        } else {
          final fresh = ChatSessionEntity(
            agentId: agentId,
            title: ChatSessionEntity.defaultTitle,
            isPinned: false,
            createdAt: now,
            updatedAt: now,
          );
          await _repository.saveSession(fresh);
          result.add(fresh);
        }
      }
      return result;
    });
  }

  Future<void> rename(String agentId, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await _repository.renameSession(agentId, trimmed);
    await load();
  }

  Future<void> togglePin(String agentId, bool currentlyPinned) async {
    await _repository.setPinned(agentId, !currentlyPinned);
    await load();
  }

  /// Clears both the session metadata and the agent's Firestore
  /// message history — starting fresh next time this agent is opened.
  Future<void> delete(String agentId) async {
    await _repository.deleteSession(agentId);
    await _chatRepository.clearMessages(agentId);
    await load();
  }

  /// Called from the Chat Screen whenever a new message arrives, so
  /// "last updated" sorting reflects real activity. Does not touch
  /// Groq or message sending in any way — purely a metadata timestamp.
  Future<void> touch(String agentId) async {
    await _repository.touchSession(agentId);
    await load();
  }
}

final chatSessionsProvider = StateNotifierProvider<ChatSessionsViewModel,
    AsyncValue<List<ChatSessionEntity>>>((ref) {
  return ChatSessionsViewModel(
    ref.watch(chatSessionRepositoryProvider),
    ref.watch(_chatRepositoryForSessionsProvider),
    () async {
      final agents = await ref.read(agentListProvider.future);
      return agents.map((a) => a.id).toList();
    },
  );
});

/// Sessions filtered by [chatSearchQueryProvider] (case-insensitive,
/// matches title) and sorted pinned-first, then newest-updated-first.
final filteredSortedSessionsProvider = Provider<List<ChatSessionEntity>>((ref) {
  final sessions = ref.watch(chatSessionsProvider).valueOrNull ?? const [];
  final query = ref.watch(chatSearchQueryProvider).trim().toLowerCase();

  final filtered = query.isEmpty
      ? sessions
      : sessions.where((s) => s.title.toLowerCase().contains(query)).toList();

  final sorted = [...filtered]
    ..sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });

  return sorted;
});
