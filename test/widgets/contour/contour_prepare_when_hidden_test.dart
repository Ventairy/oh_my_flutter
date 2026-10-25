import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;

import 'contour_initial_frame_test_binding.dart';
import 'contour_solid_test_painter.dart';
import 'contour_test_harness.dart';

void main() {
  final binding = ContourInitialFrameTestBinding();
  tearDown(binding.resetRecording);
  Object? property(GlobalKey key, String name) => key.currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .firstWhere((value) => value.name == name)
      .value;

  Widget scene({required GlobalKey key, required Widget Function(Widget) hide}) => MediaQuery(
    data: const MediaQueryData(devicePixelRatio: 1),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: hide(
          Contour(
            key: key,
            color: const Color(0xFFFFFFFF),
            amount: 3,
            child: const SizedBox.square(
              dimension: 30,
              child: CustomPaint(painter: ContourSolidTestPainter(color: Color(0xFFAA0000))),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('when an outer pop is delayed, it should leave generic contour source uncaptured during the wait', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      scene(
        key: key,
        hide: (child) => Motion(
          effect: const PopMotionEffect(delay: Duration(milliseconds: 500)),
          child: child,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    expect(property(key, 'captureCount'), 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('when an outer pop starts painting, it should prepare its generic contour source', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      scene(
        key: key,
        hide: (child) => Motion(
          effect: const PopMotionEffect(delay: Duration(milliseconds: 500)),
          child: child,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    await ContourTestHarness.settle(tester);
    expect(property(key, 'captureCount'), greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('when an outer opacity stays zero, it should leave generic contour source unready', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      scene(
        key: key,
        hide: (child) => Opacity(opacity: 0, child: child),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    expect(property(key, 'contourReady'), false);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('when prepareWhenHidden is enabled, it should prepare generic source under outer opacity zero', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 1),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Opacity(
              opacity: 0,
              child: Contour(
                key: key,
                prepareWhenHidden: true,
                color: const Color(0xFFFFFFFF),
                amount: 3,
                child: const SizedBox.square(
                  dimension: 30,
                  child: CustomPaint(painter: ContourSolidTestPainter(color: Color(0xFFAA0000))),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await ContourTestHarness.settle(tester);
    expect(property(key, 'contourReady'), true);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'when a hidden fallback source prepared in advance is revealed, it should retain prepared geometry in its first visible frame',
    (tester) async {
      // Exercise the prepared fallback's capture count at first reveal.
      ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared;
      addTearDown(() => ContourCompositeSource.testOverride = null);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size.square(100);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });
      final key = GlobalKey();
      final opacity = ValueNotifier<double>(0);
      addTearDown(opacity.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 1),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: ValueListenableBuilder<double>(
                valueListenable: opacity,
                builder: (context, value, child) => Opacity(opacity: value, child: child),
                child: Contour(
                  key: key,
                  prepareWhenHidden: true,
                  color: const Color(0xFFFFFFFF),
                  amount: 3,
                  child: const SizedBox.square(
                    dimension: 30,
                    child: CustomPaint(painter: ContourSolidTestPainter(color: Color(0xFFAA0000))),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await ContourTestHarness.settle(tester);
      binding.startRecording();
      opacity.value = 1;
      await tester.pump();
      binding.stopRecording();
      final frames = await binding.frames(tester);
      expect(
        [
          property(key, 'captureCount'),
          ContourTestHarness.pixel(frames.first, 50, 50),
          ContourTestHarness.pixel(frames.first, 33, 50),
        ],
        [
          1,
          [170, 0, 0, 255],
          [255, 255, 255, 255],
        ],
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
