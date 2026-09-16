import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/morph/morph_test_configuration.dart';

import 'morph_tag_status/tag_status_scene.dart';

void main() {
  setUp(() => MorphTestConfiguration.rasterizationEnabled = true);
  tearDown(() => MorphTestConfiguration.rasterizationEnabled = false);

  for (final matched in [true, false]) {
    for (final milliseconds in [0, 100, 400]) {
      late TagStatusScene scene;
      final name = matched ? 'matched' : 'unmatched';
      unawaited(
        goldenTest(
          'when a $name route is at ${milliseconds}ms, it should show only the selected transition',
          fileName: 'morph_tag_status_${name}_$milliseconds',
          constraints: const BoxConstraints.tightFor(width: 400, height: 700),
          builder: () {
            scene = TagStatusScene(matched: matched);
            return scene.app;
          },
          whilePerforming: (tester) async {
            scene.push();
            await tester.pump();
            await tester.pump();
            if (milliseconds > 0) await tester.pump(Duration(milliseconds: milliseconds));
            if (milliseconds == 400) await tester.pumpAndSettle();
            return tester.pumpAndSettle;
          },
        ),
      );
    }
  }
}
