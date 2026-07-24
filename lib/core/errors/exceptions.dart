/// Data-layer exceptions thrown by datasources and translated into
/// domain Failures by the repository implementation.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Thrown by [AgentResponseService] implementations (e.g. GroqService)
/// for network or API failures. [message] is short and safe to show
/// directly in the chat; [technicalDetail] is the full underlying
/// cause, meant for logging only — never shown to the user (it may
/// contain response bodies or other internals).
class AgentResponseException implements Exception {
  final String message;
  final Object? technicalDetail;

  const AgentResponseException(this.message, [this.technicalDetail]);

  @override
  String toString() => message;
}
