import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/morph/morph_test_configuration.dart';

import 'morph_scope/scope_scene.dart';

void main() {
  setUp(() => MorphTestConfiguration.rasterizationEnabled = true);
  tearDown(() => MorphTestConfiguration.rasterizationEnabled = false);
  for (final scenario in ['disabled', 'ongoing', 'control']) {
    final duringFlight = scenario != 'disabled';
    late ScopeScene scene;
    unawaited(
      goldenTest(
        'when the scope scenario is $scenario, it should preserve the expected visual',
        fileName: 'morph_scope_${duringFlight ? 'ongoing' : 'disabled'}',
        constraints: const BoxConstraints.tightFor(width: 400, height: 700),
        builder: () {
          scene = ScopeScene();
          if (!duringFlight) scene.enabled.value = false;
          return scene.app;
        },
        whilePerforming: (tester) async {
          scene.push();
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          if (scenario == 'ongoing') {
            scene.enabled.value = false;
            await tester.pump();
          }
          return tester.pumpAndSettle;
        },
      ),
    );
  }
}
