import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:oh_my_flutter/src/widgets/morph/morph_test_configuration.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final isRunningInCi = Platform.environment['CI'] == 'true';
  MorphTestConfiguration.rasterizationEnabled = false;

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
