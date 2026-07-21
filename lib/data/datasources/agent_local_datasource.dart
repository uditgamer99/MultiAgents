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
      'id': 'web-developer',
      'icon': '🌐',
      'name': 'Web Developer',
      'description':
          'Writes only HTML, CSS and JavaScript. Never writes Flutter, '
              'Python or any other language.',
    },
    {
      'id': 'marketing',
      'icon': '📈',
      'name': 'Marketing',
      'description':
          'Creates Instagram Reels, YouTube Shorts, Product Hunt launch '
              'ideas, captions and marketing content.',
    },
    {
      'id': 'ceo',
      'icon': '👑',
      'name': 'CEO',
      'description':
          'The CEO manages all AI agents. In future phases it will analyze '
              'user requests, divide them into subtasks, delegate work to '
              'specialist agents, and combine all responses into one final '
              'answer.',
    },
    {
      'id': 'flutter-developer',
      'icon': '📱',
      'name': 'Flutter Developer',
      'description':
          'Writes only Flutter (Dart) code. Builds complete Flutter apps, '
              'widgets, Riverpod, Firebase, clean architecture and mobile UI.',
    },
    {
      'id': 'ai-engineer',
      'icon': '🤖',
      'name': 'AI Engineer',
      'description':
          'Creates AI agents, prompts, automation workflows, API '
              'integrations, Python AI scripts and LLM-based applications.',
    },
    {
      'id': 'designer',
      'icon': '🎨',
      'name': 'Designer',
      'description':
          'Creates UI/UX designs, color palettes, app layouts, logos, '
              'icons, banners, thumbnails and design systems.',
    },
    {
      'id': 'researcher',
      'icon': '🔍',
      'name': 'Researcher',
      'description':
          'Researches topics, searches information, compares products, '
              'summarizes content and collects references.',
    },
  ];
}
