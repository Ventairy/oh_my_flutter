import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';

/// Configures tests that run on Dart VM platforms.
final class TestConfiguration {
  const TestConfiguration._();

  /// Runs [testMain] with the package's golden-test configuration.
  static Future<void> run(
    FutureOr<void> Function() testMain,
  ) async {
    final isRunningInCi = Platform.environment['CI'] == 'true';

    await AlchemistConfig.runWithConfig(
      config: AlchemistConfig(
        ciGoldensConfig: CiGoldensConfig(
          diffThreshold: isRunningInCi ? 0.05 : 0,
        ),
        platformGoldensConfig: PlatformGoldensConfig(
          enabled: !isRunningInCi,
        ),
      ),
      run: testMain,
    );
  }
}
