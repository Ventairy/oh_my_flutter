import 'dart:async';

import 'package:oh_my_flutter/src/widgets/morph/morph_test_configuration.dart';

import 'support/test_configuration.dart' if (dart.library.js_interop) 'support/test_configuration_web.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  MorphTestConfiguration.rasterizationEnabled = false;
  await TestConfiguration.run(testMain);
}
