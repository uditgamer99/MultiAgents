import '../entities/chat_session_entity.dart';

/// Abstract contract for local chat session metadata (title, pinned
/// state, timestamps) — deliberately separate from [ChatRepository],
/// which owns the actual message history in Firestore. Implementations
/// persist locally on-device (see [ChatSessionRepositoryImpl]).
abstract class ChatSessionRepository {
  /// All stored sessions, in no particular order — callers sort/filter.
  Future<List<ChatSessionEntity>> getAllSessions();

  /// Fetches one session, or null if it has never been created.
  Future<ChatSessionEntity?> getSession(String agentId);

  /// Creates or overwrites a session's full record.
  Future<void> saveSession(ChatSessionEntity session);

  Future<void> renameSession(String agentId, String title);

  Future<void> setPinned(String agentId, bool isPinned);

  /// Bumps `updatedAt` to now — called whenever a new message is sent,
  /// so "last updated" sorting reflects actual chat activity.
  Future<void> touchSession(String agentId);

  /// Removes the session's metadata entirely (title/pin/timestamps
  /// revert to defaults next time this agent is chatted with).
  Future<void> deleteSession(String agentId);
}
