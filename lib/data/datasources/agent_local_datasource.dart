import '../models/agent_model.dart';

/// Local (in-memory) source of agent data for Phase 3. This is the
/// only file that needs to change when agents move to Firestore —
/// swap this class's body for a Firestore query and everything above
/// it (repository, provider, UI) stays the same.
class AgentLocalDataSource {
  Future<List<AgentModel>> getAgents() async {
    return _agents.map(AgentModel.fromJson).toList();
  }

  static final List<Map<String, dynamic>> _agents = [
    {
      'id': 'ceo',
      'icon': '👑',
      'name': 'CEO',
      'description': 'Manages and coordinates all AI agents.',
    },
    {
      'id': 'web-developer',
      'icon': '🌐',
      'name': 'Web Developer',
      'description': 'Writes HTML, CSS and JavaScript.',
    },
    {
      'id': 'flutter-developer',
      'icon': '📱',
      'name': 'Flutter Developer',
      'description': 'Writes Flutter and Dart code.',
    },
    {
      'id': 'marketing',
      'icon': '📈',
      'name': 'Marketing',
      'description': 'Creates marketing content and strategies.',
    },
    {
      'id': 'ai-engineer',
      'icon': '🤖',
      'name': 'AI Engineer',
      'description': 'Builds AI agents and automations.',
    },
    {
      'id': 'designer',
      'icon': '🎨',
      'name': 'Designer',
      'description': 'Creates UI, UX and graphic designs.',
    },
    {
      'id': 'researcher',
      'icon': '🔍',
      'name': 'Researcher',
      'description': 'Researches and summarizes information.',
    },
  ];
}
