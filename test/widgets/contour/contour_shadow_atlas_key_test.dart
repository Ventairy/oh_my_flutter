import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_shadow_atlas_test_harness.dart';

void main() {
  const first = Shadow(color: Color(0x18332288), blurRadius: 6, offset: Offset(-1, 2));
  const second = Shadow(color: Color(0x10338822), blurRadius: 10, offset: Offset(2, -1));

  testWidgets('when separately allocated shadow styles are equal, it should coalesce their atlas resources', (
    tester,
  ) async {
    final harness = ContourShadowAtlasTestHarness();
    await harness.animate(
      tester,
      shadowsFor: (index) => [
        Shadow(color: Color(first.color.toARGB32()), blurRadius: 6, offset: const Offset(-1, 2)),
        Shadow(color: Color(second.color.toARGB32()), blurRadius: 10, offset: const Offset(2, -1)),
      ],
    );
    final id = harness.property('shadowAtlasResourceId')! as int;
    expect(
      (
        harness.property('shadowAtlasReady'),
        harness.property('shadowAtlasReady', 1),
        id > 0,
        id == harness.property('shadowAtlasResourceId', 1),
      ),
      (true, true, true, true),
    );
  });

  const variants = <String, List<Shadow>>{
    'color': [Shadow(color: Color(0x18332244), blurRadius: 6, offset: Offset(-1, 2)), second],
    'opacity': [Shadow(color: Color(0x20332288), blurRadius: 6, offset: Offset(-1, 2)), second],
    'blur': [Shadow(color: Color(0x18332288), blurRadius: 6.25, offset: Offset(-1, 2)), second],
    'offset': [Shadow(color: Color(0x18332288), blurRadius: 6, offset: Offset(-1.25, 2)), second],
    'order': [second, first],
  };
  for (final variant in variants.entries) {
    testWidgets('when shadow ${variant.key} changes, it should retain a distinct atlas resource', (tester) async {
      final harness = ContourShadowAtlasTestHarness();
      await harness.animate(tester, shadowsFor: (index) => index == 0 ? const [first, second] : variant.value);
      final firstId = harness.property('shadowAtlasResourceId')! as int;
      final secondId = harness.property('shadowAtlasResourceId', 1)! as int;
      expect(
        (
          harness.property('shadowAtlasReady'),
          harness.property('shadowAtlasReady', 1),
          firstId > 0 && secondId > 0,
          firstId != secondId,
        ),
        (true, true, true, true),
      );
    });
  }
}
