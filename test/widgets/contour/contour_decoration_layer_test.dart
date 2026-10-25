import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;

import 'contour_frame_test_binding.dart';
import 'contour_preflight_test_fixture.dart';
import 'contour_test_harness.dart';

void main() {
  final binding = ContourFrameTestBinding();

  setUpAll(() async {
    if (kIsWeb) return;
    await (FontLoader('ContourFrameTestRoboto')..addFont(
          File('.fvm/flutter_sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf')
              .readAsBytes()
              .then(ByteData.sublistView),
        ))
        .load();
  });

  testWidgets('when a nested source shrinks, it should hide its old backing in the first application scene', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size.square(100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(binding.resetCapture);
    final fixture = ContourPreflightTestFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.widget);
    await ContourTestHarness.settle(tester);
    binding.captureNextFrame();
    await tester.pump();
    final before = await binding.pixels(tester);

    fixture.changed.value = true;
    binding.captureNextFrame();
    await tester.pump();
    final after = await binding.pixels(tester);
    // Keep the first submitted scene above, then drain cooperative browser work
    // before the test binding checks for pending timers at teardown.
    await ContourTestHarness.settle(tester);

    expect(
      [
        ContourTestHarness.pixel(before, 35, 50),
        ContourTestHarness.pixel(before, 72, 50),
        ContourTestHarness.pixel(after, 35, 50),
        ContourTestHarness.pixel(after, 60, 50),
      ],
      [
        [0, 0, 255, 255],
        [255, 255, 255, 255],
        [0, 255, 0, 255],
        [0, 0, 0, 0],
      ],
    );
  });

  testWidgets(
    'when verified fallback text changes font, it should hide its old backing in the first application scene',
    (tester) async {
      // Exercise invalidation after the fallback's native glyph proof succeeds.
      ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared;
      addTearDown(() => ContourCompositeSource.testOverride = null);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(200, 100);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(binding.resetCapture);
      final changed = ValueNotifier(false);
      addTearDown(changed.dispose);
      Widget content() => SizedBox(
        width: 80,
        height: 40,
        child: ValueListenableBuilder(
          valueListenable: changed,
          builder: (context, value, child) => Text(
            value ? '.' : 'OO',
            style: TextStyle(
              fontFamily: value ? 'Ahem' : 'ContourFrameTestRoboto',
              fontSize: value ? 20 : 32,
              height: 1,
              color: value ? const Color(0xff00ff00) : const Color(0xff0000ff),
            ),
          ),
        ),
      );
      final contourKey = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              SizedBox.square(
                dimension: 100,
                child: Center(
                  child: Contour(
                    key: contourKey,
                    color: const Color(0xffffffff),
                    amount: 4,
                    child: RepaintBoundary(child: content()),
                  ),
                ),
              ),
              SizedBox.square(
                dimension: 100,
                child: Center(child: RepaintBoundary(child: content())),
              ),
            ],
          ),
        ),
      );
      await ContourTestHarness.settle(tester);
      final nativeBefore = contourKey.currentContext!
          .findRenderObject()!
          .toDiagnosticsNode()
          .getProperties()
          .singleWhere((property) => property.name == 'nativeTextActive')
          .value;

      changed.value = true;
      binding.captureNextFrame(size: const Size(200, 100));
      await tester.pump();
      final pixels = await binding.pixels(tester);
      var mismatches = 0;
      var visibleGreen = 0;
      for (var y = 0; y < 100; y++) {
        for (var x = 0; x < 100; x++) {
          final left = (y * 200 + x) * 4;
          final right = (y * 200 + x + 100) * 4;
          for (var channel = 0; channel < 4; channel++) {
            if (pixels[left + channel] != pixels[right + channel]) mismatches++;
          }
          if (pixels[left + 1] == 255 && pixels[left + 3] > 0) visibleGreen++;
        }
      }

      expect((nativeBefore, mismatches, visibleGreen > 0), (true, 0, true));
    },
    // The SDK font fixture is read from disk and is not bundled for browsers.
    skip: kIsWeb,
  );
}
