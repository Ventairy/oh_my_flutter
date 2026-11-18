import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'disintegrate_test_harness.dart';

void main() {
  testWidgets('when iOS is waiting for its first native image, it should preserve readiness before starting', (
    tester,
  ) async {
    final harness = DisintegrateTestHarness(tester, native: true)..firstFrame = Completer<Object?>();
    var starts = 0;
    await harness.mount(
      effect: DisintegrateMotionEffect(direction: Offset.zero, onStart: () => starts++),
    );
    await harness.start();
    final pending = (starts, find.byType(Texture).evaluate().length);
    harness.firstFrame!.complete(null);
    await harness.prepare();
    expect(
      (
        pending,
        starts,
        find.byType(Texture).evaluate().length,
        harness.calls.where((call) => call.method == 'awaitFirstFrame').length,
      ),
      ((0, 0), 1, 1, 1),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('when iOS cannot prepare native drawing, it should fall back and finish playback', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    var finishes = 0;
    await harness.mount(
      effect: DisintegrateMotionEffect(direction: Offset.zero, onEnd: () => finishes++),
    );
    await harness.start();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(
      (harness.calls.where((call) => call.method == 'prepare').length, finishes, tester.takeException()),
      (1, 1, null),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('when iOS removes an effect during first-image readiness, it should release only that image', (
    tester,
  ) async {
    final harness = DisintegrateTestHarness(tester, native: true)..firstFrame = Completer<Object?>();
    var starts = 0;
    await harness.mount(
      effect: DisintegrateMotionEffect(direction: Offset.zero, onStart: () => starts++),
    );
    await harness.start();
    await tester.pumpWidget(const SizedBox.shrink());
    harness.firstFrame!.complete(null);
    await harness.prepare();
    expect(
      (starts, harness.calls.where((call) => call.method == 'dispose').length, tester.takeException()),
      (0, 1, null),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  testWidgets(
    'when iOS is warming its renderer, it should finish the first effect without waiting for native preparation',
    (tester) async {
      final harness = DisintegrateTestHarness(tester, native: true, nativeReady: false);
      var finishes = 0;
      await harness.mount(
        effect: DisintegrateMotionEffect(direction: Offset.zero, onEnd: () => finishes++),
      );
      await harness.start();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect((finishes, harness.calls.where((call) => call.method == 'prepare').length), (1, 0));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
