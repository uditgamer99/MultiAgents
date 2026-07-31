import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/chat_message_entity.dart';
import 'chat_attachment_model.dart';

/// Maps between Firestore documents and the domain [ChatMessageEntity].
class ChatMessageModel extends ChatMessageEntity {
  const ChatMessageModel({
    required super.id,
    required super.agentId,
    required super.text,
    required super.sender,
    required super.timestamp,
    super.attachments,
  });

  factory ChatMessageModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawAttachments = data['attachments'] as List<dynamic>?;
    return ChatMessageModel(
      id: id,
      agentId: data['agentId'] as String,
      text: data['text'] as String,
      sender: (data['sender'] as String) == 'user'
          ? MessageSender.user
          : MessageSender.agent,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      // Older messages saved before the attachment system existed
      // simply have no 'attachments' field — that decodes to an
      // empty list here, not an error.
      attachments: rawAttachments == null
          ? const []
          : rawAttachments
              .map(
                (raw) => ChatAttachmentModel.fromMap(
                  Map<String, dynamic>.from(raw as Map),
                ),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'agentId': agentId,
      'text': text,
      'sender': sender == MessageSender.user ? 'user' : 'agent',
      'timestamp': Timestamp.fromDate(timestamp),
      // Omit the field entirely for the common case (no attachments)
      // rather than writing an empty array to every message document.
      if (attachments.isNotEmpty)
        'attachments': attachments
            .map((a) => ChatAttachmentModel.fromEntity(a).toMap())
            .toList(),
    };
  }
}
