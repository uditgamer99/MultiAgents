import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/agent_repository_impl.dart';
import '../../domain/entities/agent_entity.dart';
import '../../domain/repositories/agent_repository.dart';

/// DI wiring: swap this single provider to fake the repository in tests,
/// or to point at a Firestore-backed implementation later.
final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  return AgentRepositoryImpl();
});

/// Drives the Home Screen's agent cards. Modeled as a FutureProvider
/// (rather than a plain list) so the loading/error states already
/// work correctly once this is swapped for a real network call.
final agentListProvider = FutureProvider<List<AgentEntity>>((ref) {
  return ref.watch(agentRepositoryProvider).getAgents();
});
