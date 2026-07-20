import '../../domain/services/agent_response_service.dart';

/// Stand-in for the real Claude API integration. Returns a fixed
/// reply per agent after a short simulated "thinking" delay — that
/// delay is what the typing indicator reflects.
///
/// To connect Claude later: write a ClaudeAgentResponseService
/// implementing this same [AgentResponseService] interface, then
/// point `agentResponseServiceProvider` at it instead of this class.
/// Nothing else in the app needs to change.
class FakeAgentResponseService implements AgentResponseService {
  @override
  Future<String> getResponse({
    required String agentId,
    required String userMessage,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));

    switch (agentId) {
      case 'web-developer':
        return "I'm the Web Developer.\n"
            "I only generate HTML, CSS and JavaScript.";
      case 'marketing':
        return "I'm the Marketing Agent.";
      case 'manager':
        return "I'm the Manager Agent.";
      default:
        return "I'm not sure which agent you're talking to.";
    }
  }
}
