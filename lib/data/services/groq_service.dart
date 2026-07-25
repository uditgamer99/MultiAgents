import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/exceptions.dart';
import '../../domain/entities/chat_message_entity.dart';
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

  /// How many prior messages (each, not pairs) to send as context.
  /// Keeps requests bounded for very long conversations instead of
  /// resending the entire history forever. No streaming, no memory
  /// beyond this in-request context — just what the task asked for.
  static const _maxHistoryMessages = 20;

  final http.Client _client;

  GroqService({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<String> getResponse({
    required String agentId,
    required List<ChatMessageEntity> history,
    required String userMessage,
  }) async {
    if (_apiKey.isEmpty) {
      throw const AgentResponseException(
        "There's a configuration issue with the AI service. Please try again later.",
        'GROQ_API_KEY is not set. Build with --dart-define=GROQ_API_KEY=your_key.',
      );
    }

    final trimmedHistory = history.length > _maxHistoryMessages
        ? history.sublist(history.length - _maxHistoryMessages)
        : history;

    final messages = [
      {
        'role': 'system',
        'content': AgentSystemPrompts.forAgent(agentId),
      },
      // Previous user + assistant messages, oldest first, exactly as
      // they were exchanged — this is the conversation memory.
      for (final message in trimmedHistory)
        {
          'role': message.sender == MessageSender.user ? 'user' : 'assistant',
          'content': message.text,
        },
      // The message being sent right now.
      {'role': 'user', 'content': userMessage},
    ];

    http.Response response;
    try {
      response = await _client.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          // Groq's completion cap defaults low if unset, which was
          // truncating longer code generations mid-file. Kept
          // moderate (rather than the max 8192) to stay safely under
          // any per-request cap a given API key/tier might enforce.
          'max_completion_tokens': 4096,
        }),
      );
    } on SocketException catch (error) {
      // No route to the internet at all (airplane mode, no signal, DNS
      // failure, etc.) — this is a network error, not an API error.
      throw AgentResponseException(
        'No internet connection. Please check your network and try again.',
        error,
      );
    } on http.ClientException catch (error) {
      // The http package's own connection-level failure type — covers
      // cases SocketException doesn't (e.g. connection reset/refused).
      throw AgentResponseException(
        'Couldn\'t reach the AI service. Please check your connection and try again.',
        error,
      );
    }

    if (response.statusCode != 200) {
      throw AgentResponseException(
        _messageForStatus(response.statusCode, response.body),
        'Groq API error ${response.statusCode}: ${response.body}',
      );
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException catch (error) {
      throw AgentResponseException(
        'Received an unreadable response from the AI service. Please try again.',
        error,
      );
    }

    final choices = data['choices'] as List<dynamic>?;
    String? content;
    if (choices != null && choices.isNotEmpty) {
      final message = (choices.first as Map<String, dynamic>)['message'];
      if (message is Map<String, dynamic>) {
        content = message['content'] as String?;
      }
    }

    if (content == null || content.trim().isEmpty) {
      throw const AgentResponseException(
        'Received an empty response from the AI service. Please try again.',
        'Groq API returned no message content',
      );
    }

    return content.trim();
  }

  /// User-safe message per HTTP status range. For the less common
  /// cases (anything that isn't clearly auth/rate-limit/server-down)
  /// this also includes Groq's own error text — that response body is
  /// just an error description with no key or account details in it,
  /// so it's safe to surface, and it turns "unexpected error" into an
  /// actually diagnosable message instead of a dead end.
  String _messageForStatus(int statusCode, String body) {
    final groqDetail = _extractGroqErrorMessage(body);

    if (statusCode == 401 || statusCode == 403) {
      return "There's a configuration issue with the AI service. Please try again later.";
    }
    if (statusCode == 429) {
      return 'The AI service is busy right now. Please wait a moment and try again.';
    }
    if (statusCode >= 500) {
      return 'The AI service is temporarily unavailable. Please try again.';
    }
    if (groqDetail != null) {
      return 'The AI service returned an error: $groqDetail';
    }
    return 'The AI service returned an unexpected error. Please try again.';
  }

  /// Groq's error responses look like `{"error": {"message": "..."}}`.
  /// Returns null (never throws) if the body doesn't match that shape.
  String? _extractGroqErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.isNotEmpty) return message;
        }
      }
    } catch (_) {
      // Not JSON, or not the shape we expect — fall back silently.
    }
    return null;
  }
}
