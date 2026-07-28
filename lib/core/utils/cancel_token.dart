/// A simple cooperative cancellation token. One instance is created
/// per in-flight request; calling [cancel] signals it should stop.
/// Long-running operations either poll [isCancelled] at safe
/// checkpoints, or register a callback via [onCancel] to be notified
/// the moment cancellation happens (e.g. to close a network client).
class CancelToken {
  bool _isCancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _isCancelled;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Registers [listener] to run as soon as [cancel] is called. If
  /// this token is already cancelled, runs it immediately instead.
  void onCancel(void Function() listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }
}
