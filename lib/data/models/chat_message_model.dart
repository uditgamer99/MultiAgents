import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/chat_message_entity.dart';

/// Maps between Firestore documents and the domain [ChatMessageEntity].
class ChatMessageModel extends ChatMessageEntity {
  const ChatMessageModel({
    required super.id,
    required super.agentId,
    required super.text,
    required super.sender,
    required super.timestamp,
  });

  factory ChatMessageModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return ChatMessageModel(
      id: id,
      agentId: data['agentId'] as String,
      text: data['text'] as String,
      sender: (data['sender'] as String) == 'user'
          ? MessageSender.user
          : MessageSender.agent,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'agentId': agentId,
      'text': text,
      'sender': sender == MessageSender.user ? 'user' : 'agent',
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
