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
      'id': 'manager',
      'icon': '📋',
      'name': 'Manager',
      'description':
          'Creates daily tasks, project planning and workflow management.',
    },
  ];
}
