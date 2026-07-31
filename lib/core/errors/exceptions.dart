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

/// Thrown by [AttachmentPickerService] when the file picker itself
/// can't be opened or fails outright (as opposed to an individual
/// file being rejected, which is reported separately so the rest of
/// a multi-file selection can still succeed). [message] is short and
/// safe to show directly in the chat.
class AttachmentException implements Exception {
  final String message;
  const AttachmentException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a request was deliberately stopped via a [CancelToken]
/// (see core/utils/cancel_token.dart) rather than having failed. This
/// is never treated as an error to show the user — it's a clean,
/// expected outcome of tapping Stop.
class OperationCancelledException implements Exception {
  const OperationCancelledException();

  @override
  String toString() => 'Generation stopped.';
}
