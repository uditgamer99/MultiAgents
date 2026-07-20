/// Abstraction over "however the agent generates a reply". Phase 4
/// implements this with fake canned responses; a later phase swaps
/// in a Claude-API-backed implementation of this exact interface —
/// the ViewModel, screens, and usecases never change.
abstract class AgentResponseService {
  Future<String> getResponse({
    required String agentId,
    required String userMessage,
  });
}
