import 'package:equatable/equatable.dart';

/// Local metadata about one agent's conversation — title, pin state,
/// and timestamps. This sits alongside the actual message history
/// (which still lives entirely in Firestore, untouched) and is
/// managed independently: renaming, pinning, or deleting a session
/// here never touches the underlying chat messages except an
/// explicit delete, which clears them too.
class ChatSessionEntity extends Equatable {
  final String agentId;
  final String title;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatSessionEntity({
    required this.agentId,
    required this.title,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  static const String defaultTitle = 'New Chat';

  ChatSessionEntity copyWith({
    String? title,
    bool? isPinned,
    DateTime? updatedAt,
  }) {
    return ChatSessionEntity(
      agentId: agentId,
      title: title ?? this.title,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [agentId, title, isPinned, createdAt, updatedAt];
}
