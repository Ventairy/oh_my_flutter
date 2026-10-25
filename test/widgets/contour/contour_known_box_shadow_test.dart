import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_initial_frame_fence.dart';

import 'contour_shadow_atlas_test_harness.dart';
import 'contour_shadow_pool_test_harness.dart';

void main() {
  const shadows = [Shadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))];
  const rectangle = SizedBox.square(
    dimension: 24,
    child: DecoratedBox(decoration: BoxDecoration(color: Color(0xffff0000))),
  );
  const circle = SizedBox.square(
    dimension: 24,
    child: DecoratedBox(
      decoration: BoxDecoration(color: Color(0xffff0000), shape: BoxShape.circle),
    ),
  );

  testWidgets(
    'when a known opaque box has a static amount, it should paint its complete shadow without captures or bitmap snapshots',
    (
      tester,
    ) async {
      final harness = ContourShadowPoolTestHarness();
      await harness.mount(tester, count: 1, amount: 4, shadows: shadows, childFor: (_) => rectangle);

      expect(
        (
          harness.property('declaredPathActive'),
          harness.property('lastMainCompositionHasContour'),
          harness.property('captureCount'),
          harness.property('shadowCacheBuildCount'),
          harness.property('shadowAtlasBuildCount'),
          (await harness.pixels(tester))[(37 * 640 + 20) * 4 + 3] > 0,
        ),
        (true, true, 0, 0, 0, true),
      );
    },
  );

  testWidgets(
    'when a known opaque box animates amounts, it should keep the complete shadow visible without captures or an atlas',
    (tester) async {
      final harness = ContourShadowAtlasTestHarness();
      await harness.animate(tester, count: 1, shadows: shadows, childFor: (_) => rectangle);

      expect(
        (
          harness.property('declaredPathActive'),
          harness.property('lastMainCompositionHasContour'),
          harness.property('captureCount'),
          harness.property('shadowCacheBuildCount'),
          harness.property('shadowAtlasBuildCount'),
          (await harness.pixels(tester))[(37 * 640 + 20) * 4 + 3] > 0,
        ),
        (true, true, 0, 0, 0, true),
      );
    },
  );

  testWidgets(
    'when a known box changes after composition, it should paint the current circle and shadow without bitmap snapshots',
    (tester) async {
      final harness = ContourShadowAtlasTestHarness();
      Widget source(int index) => index == 0 ? rectangle : circle;
      await harness.mount(tester, count: 2, amount: 4, shadows: shadows, childFor: source);
      final previousReady = harness.property('knownBoxFillActive');
      final previousResource = harness.property('shadowResourceId');
      final previousBuilds = harness.property('shadowCacheBuildCount');
      await harness.mount(tester, count: 2, amount: 5, shadows: shadows, childFor: source, settle: false);
      final decorated = tester.renderObject<RenderDecoratedBox>(
        find.descendant(of: find.byKey(harness.keys.first), matching: find.byType(DecoratedBox)),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Mutate after the submitted composition to exercise source validation
        // without relying on the optional sampled-shadow debounce.
        decorated.decoration = const BoxDecoration(color: Color(0xffff0000), shape: BoxShape.circle);
      });
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 121));
      final rejectedSnapshot = (
        harness.property('shadowResourceId'),
        harness.property('shadowCacheReady'),
        harness.property('shadowCacheBuildCount') == previousBuilds,
      );
      await harness.settle(tester);
      final pixels = await harness.pixels(tester);

      expect(
        (
          previousReady,
          rejectedSnapshot,
          harness.property('knownBoxFillActive'),
          harness.property('shadowResourceId') == previousResource,
          harness.property('captureCount'),
          harness.mismatchedCells(pixels, 2),
        ),
        (true, (0, false, true), true, true, 0, 0),
      );
    },
  );

  testWidgets(
    'when a known box becomes translucent during amount changes, it should discard the old backing and leave only visible child pixels',
    (tester) async {
      final harness = ContourShadowAtlasTestHarness();
      await harness.animate(tester, count: 1, shadows: shadows, childFor: (_) => rectangle);
      final previousReady = harness.property('knownBoxFillActive');
      await harness.mount(tester, count: 1, amount: 12, shadows: shadows, childFor: (_) => rectangle, settle: false);
      await harness.mount(
        tester,
        count: 1,
        amount: 12,
        shadows: shadows,
        settle: false,
        childFor: (_) => const SizedBox.square(
          dimension: 24,
          child: DecoratedBox(decoration: BoxDecoration(color: Color(0x05ff0000))),
        ),
      );
      final changed = (
        harness.property('declaredPathActive'),
        harness.property('lastMainCompositionHasContour'),
        harness.property('shadowAtlasResourceId'),
        harness.property('shadowAtlasReady'),
      );
      await harness.settle(tester);
      final pixels = await harness.pixels(tester);
      var maximumAlpha = 0;
      for (var index = 3; index < pixels.length; index += 4) {
        if (pixels[index] > maximumAlpha) maximumAlpha = pixels[index];
      }

      expect((previousReady, changed, maximumAlpha), (true, (false, false, 0, false), 5));
    },
  );

  testWidgets(
    'when foreground work is waiting, it should paint known-box shadows without queuing primitive snapshots',
    (tester) async {
      final harness = ContourShadowAtlasTestHarness();
      final fence = ContourInitialFrameFence.shared;
      var held = false;
      addTearDown(() {
        if (held) fence.endForeground();
      });
      List<Shadow> sourceShadows(int index, double offset) =>
          index == 0 ? [Shadow(color: const Color(0x33000000), blurRadius: 6, offset: Offset(offset, 2))] : const [];
      await harness.animate(
        tester,
        count: 2,
        shadowsFor: (index) => sourceShadows(index, .31),
        childFor: (_) => rectangle,
      );
      final previousReady = harness.property('knownBoxFillActive');
      await harness.mount(
        tester,
        count: 2,
        amount: 4,
        shadowsFor: (index) => sourceShadows(index, .41),
        childFor: (_) => rectangle,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 121));
      fence.beginForeground();
      held = true;
      await tester.pump();
      final queued = harness.property('shadowAtlasQueuedJobs', 1)! as int;
      final bytes = harness.property('shadowAtlasSnapshotBytes', 1)! as int;
      await harness.mount(
        tester,
        count: 2,
        amount: 4,
        shadowsFor: (index) => sourceShadows(index, .41),
        childFor: (_) => rectangle,
        showFor: (index) => index != 0,
        settle: false,
      );
      await tester.runAsync(Future<void>.value);
      final afterDetach = (
        harness.property('shadowAtlasSnapshotBytes', 1),
        harness.property('shadowAtlasQueuedJobs', 1),
      );
      fence.endForeground();
      held = false;
      await harness.settle(tester);

      expect(
        (previousReady, queued, bytes, harness.property('lastMainCompositionHasContour', 1), afterDetach),
        (true, 0, 0, true, (0, 0)),
      );
    },
  );
}
