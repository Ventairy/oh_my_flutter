import 'dart:async';

/// Configures tests that run on the web.
final class TestConfiguration {
  const TestConfiguration._();

  /// Runs [testMain] without VM-only golden-test infrastructure.
  static Future<void> run(
    FutureOr<void> Function() testMain,
  ) async {
    await testMain();
  }
}
