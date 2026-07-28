import 'package:flutter/material.dart';

import '../../../../core/utils/code_file_parser.dart';
import '../../../../domain/entities/chat_message_entity.dart';
import 'code_file_card.dart';

/// Agent ids whose replies may contain "📄 filename" code blocks —
/// only these get parsed for file cards; every other agent's
/// messages render as plain text, unchanged.
const _fileCapableAgentIds = {
  'ceo',
  'web-developer',
  'flutter-developer',
  'ai-engineer',
};

/// A single chat bubble — right-aligned + primary color for the
/// user, left-aligned + neutral surface for the agent. Shows the
/// message text and a small timestamp underneath. For the 4
/// file-capable agents, any "📄 filename" blocks in an agent reply
/// are rendered as [CodeFileCard]s with copy/share actions instead
/// of raw text.
///
/// [showRegenerate] adds a small regenerate icon next to the
/// timestamp — only meaningful for agent messages. [isRegenerating]
/// shows a spinner there instead while this exact message is being
/// regenerated; [regenerateEnabled] disables the icon (without
/// hiding it) while any other send/regenerate is in flight.
class MessageBubble extends StatelessWidget {
  final ChatMessageEntity message;
  final bool showRegenerate;
  final bool isRegenerating;
  final bool regenerateEnabled;
  final VoidCallback? onRegenerate;

  const MessageBubble({
    super.key,
    required this.message,
    this.showRegenerate = false,
    this.isRegenerating = false,
    this.regenerateEnabled = true,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor =
        isUser ? colorScheme.primary : colorScheme.surfaceContainerHigh;
    final textColor = isUser ? colorScheme.onPrimary : colorScheme.onSurface;

    final canHaveFiles = !isUser && _fileCapableAgentIds.contains(message.agentId);
    final parsed = canHaveFiles ? parseCodeFiles(message.text) : null;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (parsed != null && parsed.hasFiles) ...[
              if (parsed.introText.isNotEmpty)
                Text(parsed.introText, style: TextStyle(color: textColor)),
              for (final file in parsed.files) CodeFileCard(file: file),
            ] else
              Text(message.text, style: TextStyle(color: textColor)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showRegenerate) ...[
                  _RegenerateIcon(
                    isRegenerating: isRegenerating,
                    enabled: regenerateEnabled,
                    color: textColor,
                    onPressed: onRegenerate,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _RegenerateIcon extends StatelessWidget {
  final bool isRegenerating;
  final bool enabled;
  final Color color;
  final VoidCallback? onPressed;

  const _RegenerateIcon({
    required this.isRegenerating,
    required this.enabled,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isRegenerating) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.7)),
        ),
      );
    }

    return Tooltip(
      message: 'Regenerate',
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            Icons.refresh,
            size: 14,
            color: color.withValues(alpha: enabled ? 0.65 : 0.3),
          ),
        ),
      ),
    );
  }
}
