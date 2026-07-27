import '../../domain/entities/chat_session_entity.dart';

/// Maps [ChatSessionEntity] to/from the JSON shape stored in
/// SharedPreferences.
class ChatSessionModel extends ChatSessionEntity {
  const ChatSessionModel({
    required super.agentId,
    required super.title,
    required super.isPinned,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ChatSessionModel.fromJson(String agentId, Map<String, dynamic> json) {
    return ChatSessionModel(
      agentId: agentId,
      title: json['title'] as String? ?? ChatSessionEntity.defaultTitle,
      isPinned: json['isPinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  factory ChatSessionModel.fromEntity(ChatSessionEntity entity) {
    return ChatSessionModel(
      agentId: entity.agentId,
      title: entity.title,
      isPinned: entity.isPinned,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'isPinned': isPinned,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
