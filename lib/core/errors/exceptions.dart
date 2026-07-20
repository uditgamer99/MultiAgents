/// Data-layer exceptions thrown by datasources and translated into
/// domain Failures by the repository implementation.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
