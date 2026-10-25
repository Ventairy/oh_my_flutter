import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;

import 'contour_preflight_test_fixture.dart';
import 'contour_test_harness.dart';

void main() {
  testWidgets(
    'when two boundaries export in one frame, it should build independent scenes without recapturing the source',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size.square(100);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final fixture = ContourPreflightTestFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.widget);
      await ContourTestHarness.settle(tester);
      final captures = fixture.captureCount;

      // Both exports compose before either GPU readback completes. Force each
      // decoration to compose so this also exercises its source observation.
      final images = await tester.runAsync(() async {
        fixture.recomposeDecorations();
        final outer = fixture.capture(key: fixture.boundaryKey);
        fixture.recomposeDecorations();
        final inner = fixture.capture(key: fixture.innerBoundaryKey);
        return await Future.wait([outer, inner]);
      });
      final outer = images![0];
      final inner = images[1];
      addTearDown(outer.dispose);
      addTearDown(inner.dispose);
      final outerPixels = await fixture.imagePixels(tester, outer);
      final innerPixels = await fixture.imagePixels(tester, inner);
      await ContourTestHarness.settle(tester);

      expect(
        (
          (outer.width, outer.height),
          (inner.width, inner.height),
          ContourPreflightTestFixture.imagePixel(outerPixels, width: outer.width, x: 35, y: 50),
          ContourPreflightTestFixture.imagePixel(outerPixels, width: outer.width, x: 28, y: 50),
          ContourPreflightTestFixture.imagePixel(innerPixels, width: inner.width, x: 25, y: 40),
          ContourPreflightTestFixture.imagePixel(innerPixels, width: inner.width, x: 18, y: 40),
          fixture.captureCount,
          fixture.diagnostic('generating'),
          tester.takeException(),
        ),
        (
          (100, 100),
          (80, 80),
          (0, 0, 255, 255),
          (255, 255, 255, 255),
          (0, 0, 255, 255),
          (255, 255, 255, 255),
          captures,
          false,
          null,
        ),
      );
    },
  );

  testWidgets('when the fallback source repaints, it should recapture once and settle with the updated backing', (
    tester,
  ) async {
    // Exercise fallback source observation and its capture counter.
    ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared;
    addTearDown(() => ContourCompositeSource.testOverride = null);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size.square(100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final fixture = ContourPreflightTestFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.widget);
    await ContourTestHarness.settle(tester);
    final captures = fixture.captureCount;

    fixture.changed.value = true;
    await tester.pump();
    await ContourTestHarness.settle(tester);
    final image = await tester.runAsync(() => fixture.capture(key: fixture.boundaryKey));
    addTearDown(image!.dispose);
    final pixels = await fixture.imagePixels(tester, image);
    for (var frame = 0; frame < 5; frame++) {
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
    }
    await ContourTestHarness.settle(tester);

    expect(
      (
        ContourPreflightTestFixture.imagePixel(pixels, width: image.width, x: 35, y: 50),
        ContourPreflightTestFixture.imagePixel(pixels, width: image.width, x: 42, y: 50),
        ContourPreflightTestFixture.imagePixel(pixels, width: image.width, x: 60, y: 50),
        captures,
        fixture.captureCount,
        fixture.diagnostic('contourReady'),
        fixture.diagnostic('generating'),
        tester.binding.hasScheduledFrame,
        tester.takeException(),
      ),
      ((0, 255, 0, 255), (255, 255, 255, 255), (0, 0, 0, 0), 1, 2, true, false, false, null),
    );
  });

  testWidgets(
    'when nested fallback contours recompose, it should refresh the outer backing without duplicating scene layers',
    (tester) async {
      // Exercise fallback source observation and its capture counter.
      ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared;
      addTearDown(() => ContourCompositeSource.testOverride = null);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size.square(100);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final fixture = ContourPreflightTestFixture(nested: true);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.widget);
      await ContourTestHarness.settle(tester);
      final image = await tester.runAsync(() {
        fixture.recomposeDecorations();
        return fixture.capture(key: fixture.boundaryKey);
      });
      addTearDown(image!.dispose);
      final pixels = await fixture.imagePixels(tester, image);
      await ContourTestHarness.settle(tester);
      final settledImage = await tester.runAsync(() => fixture.capture(key: fixture.boundaryKey));
      addTearDown(settledImage!.dispose);
      final settledPixels = await fixture.imagePixels(tester, settledImage);

      expect(
        (
          ContourPreflightTestFixture.imagePixel(pixels, width: image.width, x: 35, y: 50),
          ContourPreflightTestFixture.imagePixel(pixels, width: image.width, x: 24, y: 50),
          ContourPreflightTestFixture.imagePixel(settledPixels, width: settledImage.width, x: 24, y: 50),
          find
              .byType(Contour)
              .evaluate()
              .every(
                (element) =>
                    element.renderObject!
                        .toDiagnosticsNode()
                        .getProperties()
                        .singleWhere((property) => property.name == 'contourReady')
                        .value ==
                    true,
              ),
          tester.takeException(),
        ),
        ((0, 0, 255, 255), (0, 0, 0, 0), (255, 255, 255, 255), true, null),
      );
    },
  );
}
