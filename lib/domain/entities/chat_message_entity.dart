import 'package:equatable/equatable.dart';

import 'chat_attachment_entity.dart';

enum MessageSender { user, agent }

/// Domain-layer representation of a single chat message, scoped to
/// one agent's conversation via [agentId].
class ChatMessageEntity extends Equatable {
  final String id;
  final String agentId;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  /// Files attached to this message, if any. Metadata only — see
  /// [ChatAttachmentEntity]. Empty for every message that predates
  /// the attachment system, and for ordinary text-only messages.
  final List<ChatAttachmentEntity> attachments;

  const ChatMessageEntity({
    required this.id,
    required this.agentId,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.attachments = const [],
  });

  @override
  List<Object?> get props =>
      [id, agentId, text, sender, timestamp, attachments];
}
