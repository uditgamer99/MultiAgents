import 'dart:developer' as developer;

/// Lightweight app-wide logger. Wraps `dart:developer.log` so messages
/// show up in `flutter logs` / Logcat / DevTools with a consistent
/// name and, on errors, the stack trace attached — instead of silently
/// swallowing exceptions that would otherwise leave the UI stuck
/// (e.g. a chat send that hangs with no visible cause).
class AppLogger {
  AppLogger._();

  static void info(String message, {String name = 'DUO_AI'}) {
    developer.log(message, name: name);
  }

  static void error(
    String message,
    Object error, [
    StackTrace? stackTrace,
    String name = 'DUO_AI',
  ]) {
    developer.log(
      message,
      name: name,
      error: error,
      stackTrace: stackTrace,
      level: 1000, // SEVERE
    );
  }
}
