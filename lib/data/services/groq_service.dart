import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/services/agent_response_service.dart';

/// Real AI backing for chat replies, via Groq's OpenAI-compatible
/// Chat Completions API. Implements the same [AgentResponseService]
/// contract the fake placeholder service used — nothing above this
/// layer (usecases, ViewModel, screens) had to change to adopt it.
///
/// The API key is never hardcoded: it's read at build time from
/// `--dart-define=GROQ_API_KEY=...`, which keeps it out of source
/// control entirely. If it's missing, [getResponse] throws immediately
/// with a clear message instead of silently failing.
class GroqService implements AgentResponseService {
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';

  static const _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const _model = String.fromEnvironment(
    'GROQ_MODEL',
    defaultValue: 'openai/gpt-oss-20b',
  );

  final http.Client _client;

  GroqService({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<String> getResponse({
    required String agentId,
    required String userMessage,
  }) async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'GROQ_API_KEY is not set. Build with '
        '--dart-define=GROQ_API_KEY=your_key (or wire it into CI).',
      );
    }

    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': _systemPromptFor(agentId)},
          {'role': 'user', 'content': userMessage},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Groq API error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    final content = (choices != null && choices.isNotEmpty)
        ? (choices.first as Map<String, dynamic>)['message']
            ?['content'] as String?
        : null;

    if (content == null || content.trim().isEmpty) {
      throw const FormatException('Groq API returned an empty response.');
    }

    return content.trim();
  }

  String _systemPromptFor(String agentId) {
    return _systemPrompts[agentId] ?? _systemPrompts['default']!;
  }

  /// One system prompt per agent — this is what actually gives each
  /// agent its distinct behavior now that replies are real.
  static const Map<String, String> _systemPrompts = {
    'ceo': 'You are the CEO agent inside a multi-agent AI app called '
        'DUO AI. You oversee the other specialist agents (Web Developer, '
        'Flutter Developer, Marketing, AI Engineer, Designer, Researcher). '
        'You do not yet delegate tasks to them — that comes in a future '
        'update. For now, respond helpfully and briefly as the CEO.',
    'web-developer': 'You are the Web Developer agent. You only write '
        'HTML, CSS and JavaScript. Never write Flutter, Python, or any '
        'other language or framework, even if asked.',
    'flutter-developer': 'You are the Flutter Developer agent. You only '
        'write Flutter and Dart code. Never write HTML, CSS, JavaScript, '
        'Python, or any other language or framework, even if asked.',
    'marketing': 'You are the Marketing agent. You create marketing '
        'strategies, content ideas, captions and campaign concepts — '
        'e.g. Instagram Reels, YouTube Shorts, Product Hunt launches.',
    'ai-engineer': 'You are the AI Engineer agent. You build AI agents, '
        'prompts, automation workflows, API integrations and LLM-based '
        'applications.',
    'designer': 'You are the Designer agent. You create UI/UX designs, '
        'color palettes, layouts, logos, icons and design systems.',
    'researcher': 'You are the Researcher agent. You research topics, '
        'compare options, summarize information and collect references.',
    'default': 'You are a helpful assistant.',
  };
}
