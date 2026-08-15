import 'dart:async';

import 'package:oh_my_flutter/src/widgets/morph/morph_test_configuration.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  MorphTestConfiguration.rasterizationEnabled = false;
  await testMain();
}
