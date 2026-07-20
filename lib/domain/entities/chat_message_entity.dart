import 'package:equatable/equatable.dart';

enum MessageSender { user, agent }

/// Domain-layer representation of a single chat message, scoped to
/// one agent's conversation via [agentId].
class ChatMessageEntity extends Equatable {
  final String id;
  final String agentId;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  const ChatMessageEntity({
    required this.id,
    required this.agentId,
    required this.text,
    required this.sender,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, agentId, text, sender, timestamp];
}
