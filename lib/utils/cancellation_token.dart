/// A simple token to signal cancellation to asynchronous operations.
class CancellationToken {
  bool _isCancelled = false;

  /// Returns `true` if cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Requests cancellation.
  void cancel() {
    _isCancelled = true;
  }
}

/// An exception thrown when an operation is cancelled.
class CancellationException implements Exception {
  final String message;

  CancellationException(this.message);

  @override
  String toString() => 'CancellationException: $message';
}