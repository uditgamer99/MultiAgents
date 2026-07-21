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
      case 'ceo':
        return "I am the CEO. In future updates I will coordinate all "
            "specialist AI agents.";
      case 'web-developer':
        return "I only write HTML, CSS and JavaScript.";
      case 'flutter-developer':
        return "I only write Flutter and Dart.";
      case 'marketing':
        return "I create marketing strategies and content.";
      case 'ai-engineer':
        return "I build AI agents, automation and AI systems.";
      case 'designer':
        return "I create UI, UX and graphic designs.";
      case 'researcher':
        return "I research information and summarize findings.";
      default:
        return "I'm not sure which agent you're talking to.";
    }
  }
}
