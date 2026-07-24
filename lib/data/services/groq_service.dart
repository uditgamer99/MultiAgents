import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/services/agent_response_service.dart';
import '../constants/agent_system_prompts.dart';

/// Real AI backing for chat replies, via Groq's OpenAI-compatible
/// Chat Completions API. Implements the same [AgentResponseService]
/// contract the fake placeholder service used — nothing above this
/// layer (usecases, ViewModel, screens) had to change to adopt it.
///
/// Every agent shares this exact same service and model — the only
/// thing that differs per agent is the system prompt, looked up from
/// [AgentSystemPrompts].
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
          {
            'role': 'system',
            'content': AgentSystemPrompts.forAgent(agentId),
          },
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
}
