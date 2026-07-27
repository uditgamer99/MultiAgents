import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/routing/route_names.dart';
import '../../../domain/entities/agent_entity.dart';
import '../../../domain/entities/chat_session_entity.dart';
import '../../providers/agent_list_provider.dart';
import '../../providers/chat_session_provider.dart';
import '../../widgets/loading_indicator.dart';
import 'widgets/chat_session_tile.dart';
import 'widgets/rename_chat_dialog.dart';

/// Manage-your-chats screen: instant search, pin/unpin, rename,
/// delete, with pinned chats always sorted to the top and everything
/// else newest-updated-first. Reached from Home's app bar; tapping a
/// row still opens the exact same /chat/{agentId} screen as before —
/// nothing about the actual chat/Groq flow changes here.
class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  AgentEntity? _findAgent(List<AgentEntity> agents, String agentId) {
    for (final agent in agents) {
      if (agent.id == agentId) return agent;
    }
    return null;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ChatSessionEntity session,
    String agentName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(
          'This permanently deletes your conversation with $agentName. '
          'This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(chatSessionsProvider.notifier).delete(session.agentId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsState = ref.watch(chatSessionsProvider);
    final agents = ref.watch(agentListProvider).valueOrNull ?? const [];
    final visibleSessions = ref.watch(filteredSortedSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.padMd,
              AppSizes.padSm,
              AppSizes.padMd,
              AppSizes.padSm,
            ),
            child: TextField(
              onChanged: (value) =>
                  ref.read(chatSearchQueryProvider.notifier).state = value,
              decoration: const InputDecoration(
                hintText: 'Search chats',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: sessionsState.when(
              loading: () => const LoadingIndicator(),
              error: (error, _) =>
                  Center(child: Text('Couldn\'t load chats: $error')),
              data: (_) {
                if (agents.isEmpty) {
                  return const LoadingIndicator();
                }
                if (visibleSessions.isEmpty) {
                  return Center(
                    child: Text(
                      'No chats found',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.padMd,
                    0,
                    AppSizes.padMd,
                    AppSizes.padMd,
                  ),
                  itemCount: visibleSessions.length,
                  itemBuilder: (context, index) {
                    final session = visibleSessions[index];
                    final agent = _findAgent(agents, session.agentId);
                    if (agent == null) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.padSm),
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(session.agentId),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 200),
                        builder: (context, value, child) => Opacity(
                          opacity: value,
                          child: child,
                        ),
                        child: ChatSessionTile(
                          session: session,
                          agent: agent,
                          onTap: () =>
                              context.push(RouteNames.chatPath(agent.id)),
                          onTogglePin: () => ref
                              .read(chatSessionsProvider.notifier)
                              .togglePin(agent.id, session.isPinned),
                          onRename: () async {
                            final newTitle = await showRenameChatDialog(
                              context,
                              currentTitle: session.title,
                            );
                            if (newTitle != null &&
                                newTitle.trim().isNotEmpty) {
                              await ref
                                  .read(chatSessionsProvider.notifier)
                                  .rename(agent.id, newTitle);
                            }
                          },
                          onDelete: () => _confirmDelete(
                            context,
                            ref,
                            session,
                            agent.name,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
