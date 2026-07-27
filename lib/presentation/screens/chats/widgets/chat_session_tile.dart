import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/entities/agent_entity.dart';
import '../../../../domain/entities/chat_session_entity.dart';

/// One row in the chat list: pin toggle, agent icon + name, the
/// session's own title, last-updated time, and a rename/delete menu.
/// Purely presentational — all actions are passed in as callbacks.
class ChatSessionTile extends StatelessWidget {
  final ChatSessionEntity session;
  final AgentEntity agent;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const ChatSessionTile({
    super.key,
    required this.session,
    required this.agent,
    required this.onTap,
    required this.onTogglePin,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: session.isPinned
          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
          : colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.padMd,
            vertical: 10,
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: IconButton(
                  key: ValueKey(session.isPinned),
                  tooltip: session.isPinned ? 'Unpin' : 'Pin',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    session.isPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    color: session.isPinned ? colorScheme.primary : null,
                    size: 20,
                  ),
                  onPressed: onTogglePin,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(agent.icon, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            session.title,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${agent.name} · ${_formatTime(session.updatedAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'rename') onRename();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    if (isToday) return '$hour:$minute';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} $hour:$minute';
  }
}
