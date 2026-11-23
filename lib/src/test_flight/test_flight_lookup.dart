/// Shares an installation-source lookup until it succeeds.
final class TestFlightLookup {
  /// Uses the supplied native lookup on demand.
  new(this._lookup);

  final Future<bool?> Function() _lookup;
  Future<bool>? _result;

  /// Returns false for an unavailable source and retries on the next read.
  Future<bool> get value => _result ??= _read();

  Future<bool> _read() async {
    bool? confirmed;
    try {
      confirmed = await _lookup();
      return confirmed ?? false;
    } finally {
      if (confirmed == null) _result = null;
    }
  }
}
