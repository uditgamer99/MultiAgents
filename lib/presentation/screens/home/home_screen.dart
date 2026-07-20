import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/routing/route_names.dart';
import '../../providers/agent_list_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/loading_indicator.dart';
import 'widgets/agent_card.dart';

/// Dashboard listing every AI agent, loaded dynamically from
/// [agentListProvider]. Tapping a card navigates to /chat/{agentId} —
/// the Chat Screen itself is built in a later phase.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentListProvider);
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('DUO AI'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authViewModelProvider.notifier).signOut(),
          ),
        ],
      ),
      body: agentsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => Center(child: Text('Couldn\'t load agents: $error')),
        data: (agents) => ListView.separated(
          padding: const EdgeInsets.all(AppSizes.padMd),
          itemCount: agents.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: AppSizes.padSm),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.padSm),
                child: Text(
                  'Signed in as $email',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              );
            }
            final agent = agents[index - 1];
            return AgentCard(
              agent: agent,
              onTap: () => context.push(RouteNames.chatPath(agent.id)),
            );
          },
        ),
      ),
    );
  }
}
