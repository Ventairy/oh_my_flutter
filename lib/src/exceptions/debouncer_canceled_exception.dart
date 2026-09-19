/// Signals that a debounced result was canceled before it could be delivered.
final class DebouncerCanceledException implements Exception {
  /// Creates a debouncer cancellation exception.
  const new();

  @override
  String toString() => 'The debounced result was canceled.';
}
