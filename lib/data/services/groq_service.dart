import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/exceptions.dart';
import '../../core/utils/cancel_token.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/routing_decision_entity.dart';
import '../../domain/services/agent_response_service.dart';
import '../constants/agent_system_prompts.dart';
import 'ceo_classification_parser.dart';

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
  /// Kept modest — not just for request size, but because Groq's
  /// free/on-demand tier enforces an 8000 tokens-per-minute cap per
  /// request, and long code replies in history eat that budget fast.
  static const _maxHistoryMessages = 6;

  /// Each history message is truncated to this many characters before
  /// being sent, so a single long previous code reply can't dominate
  /// the token budget on its own (roughly 375 tokens per message at
  /// ~4 characters/token).
  static const _maxHistoryMessageChars = 1500;

  /// Creates a fresh http.Client for each request (rather than one
  /// shared client reused forever) so that cancelling one in-flight
  /// request — by closing its own client — can never affect any other
  /// request, past or future.
  final http.Client Function() _clientFactory;

  GroqService({http.Client Function()? clientFactory})
      : _clientFactory = clientFactory ?? (() => http.Client());

  @override
  Future<String> getResponse({
    required String agentId,
    required List<ChatMessageEntity> history,
    required String userMessage,
    CancelToken? cancelToken,
  }) async {
    if (_apiKey.isEmpty) {
      throw const AgentResponseException(
        "There's a configuration issue with the AI service. Please try again later.",
        'GROQ_API_KEY is not set. Build with --dart-define=GROQ_API_KEY=your_key.',
      );
    }

    if (cancelToken != null && cancelToken.isCancelled) {
      throw const OperationCancelledException();
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
      // they were exchanged (truncated so no single long reply blows
      // the token budget) — this is the conversation memory.
      for (final message in trimmedHistory)
        {
          'role': message.sender == MessageSender.user ? 'user' : 'assistant',
          'content': _truncate(message.text, _maxHistoryMessageChars),
        },
      // The message being sent right now.
      {'role': 'user', 'content': userMessage},
    ];

    final client = _clientFactory();

    // If Stop is tapped while this request is in flight, closing its
    // own (not-shared-with-anyone-else) client aborts it at the socket
    // level almost immediately.
    cancelToken?.onCancel(() {
      client.close();
    });

    http.Response response;
    try {
      response = await client.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          // Reserved output space. Kept well under Groq's free-tier
          // 8000 tokens-per-minute cap once combined with the system
          // prompt, history, and user message.
          'max_completion_tokens': 2048,
        }),
      );
    } catch (error) {
      // Cancellation takes priority over how the abort happened to
      // manifest — whatever exception type closing the client during
      // an in-flight request produced, treat it as a clean stop, not
      // a network failure, whenever cancellation was actually asked
      // for.
      if (cancelToken != null && cancelToken.isCancelled) {
        throw const OperationCancelledException();
      }
      if (error is http.ClientException) {
        throw AgentResponseException(
          'Couldn\'t reach the AI service. Please check your connection and try again.',
          error,
        );
      }
      throw AgentResponseException(
        'No internet connection. Please check your network and try again.',
        error,
      );
    } finally {
      client.close();
    }

    if (cancelToken != null && cancelToken.isCancelled) {
      // The response arrived right as Stop was tapped — discard it
      // rather than saving something the user no longer wants.
      throw const OperationCancelledException();
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

    final trimmedContent = content.trim();

    // Phase 3.1 Part 1A: the CEO's reply is a classification, not a
    // normal chat answer. Parse it purely to prove the classification
    // pipeline works end to end (logged for now) — this never changes
    // what's shown in the chat or saved to history, and no other
    // agent is affected at all.
    if (agentId == 'ceo') {
      final classification = CeoClassificationParser.parse(trimmedContent);
      final routing = RoutingDecisionEntity.fromClassification(classification);
      AppLogger.info(
        'CEO routing decision — selectedAgentIds: '
        '${routing.selectedAgentIds.join(', ')}; taskType: '
        '${routing.taskType}; confidence: ${routing.confidence}; '
        'reason: ${routing.reason}',
      );

      // Phase 3.1 Part 1B: routing is intentionally not executed yet —
      // this line exists purely so the routing decision is visible
      // for testing, since it can't be checked any other way here.
      // Safe to remove once a later phase actually executes routing
      // and this becomes purely internal/logged.
      return '$trimmedContent\n\n[Routing → ${routing.selectedAgentIds.join(', ')}]';
    }

    return trimmedContent;
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

  String _truncate(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}\n…(truncated)';
  }
}
