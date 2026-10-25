import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_native_test_harness.dart';

void main() {
  testWidgets('when equivalent glyphs mount together, it should share their accepted source capture', (tester) async {
    final harness = ContourNativeTestHarness();
    await harness.mountPair(tester);
    expect(
      [
        harness.firstKey,
        harness.secondKey,
      ].where((key) => (harness.diagnostic('captureCount', key: key)! as int) > 0).length,
      1,
    );
  });

  testWidgets('when a verified backing is shared, it should preserve glyph and shadow pixels', (tester) async {
    final harness = ContourNativeTestHarness();
    await harness.mountPair(tester);
    final (owner, follower) = await harness.pairPixels(tester);
    var mismatches = 0;
    for (var index = 0; index < owner.length; index++) {
      // CanvasKit rounds translated Gaussian alpha samples differently even
      // with plain native glyph masks. Keep RGB and all non-web samples exact.
      final tolerance = kIsWeb && index % 4 == 3 ? 1 : 0;
      if ((follower[index] - owner[index]).abs() > tolerance) mismatches++;
    }
    expect(mismatches, 0);
  });

  testWidgets('when a verified backing is shared, it should preserve the owner paint overflow bounds', (tester) async {
    final harness = ContourNativeTestHarness();
    await harness.mountPair(tester);
    expect(harness.paintBounds(harness.secondKey), harness.paintBounds(harness.firstKey));
  });
}
