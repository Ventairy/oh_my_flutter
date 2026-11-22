import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'disintegrate_test_harness.dart';

void main() {
  for (final (transition, initialPose) in [('leaves the first moving pose', .056), ('reverses from a late pose', .9)]) {
    testWidgets('when a blurred breakup $transition, it should match a fresh breakup at the same pose', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final harness = DisintegrateTestHarness(tester);
      const child = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x66305AB0), Color(0xFFF8AD39), Color(0xD0DD4172)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: SizedBox(width: 120, height: 58),
      );
      await harness.mount(
        effect: _BlurredBreakup(initialPose: initialPose),
        child: child,
      );
      await harness.start();
      await tester.pump(const Duration(milliseconds: 80));
      final initialPixels = await harness.pixels(pixelRatio: 2);
      await tester.pump(const Duration(milliseconds: 160));
      final transitionedPixels = await harness.pixels(pixelRatio: 2);

      await tester.pumpWidget(const SizedBox.shrink());
      await harness.mount(effect: const _BlurredBreakup(), child: child);
      await harness.start();
      await tester.pump(const Duration(milliseconds: 80));
      final freshEarlyPixels = await harness.pixels(pixelRatio: 2);

      expect([transitionedPixels, initialPixels], [equals(freshEarlyPixels), isNot(equals(freshEarlyPixels))]);
    });
  }
}

class _BlurredBreakup extends MotionEffect {
  const new({this.initialPose}) : super(duration: const Duration(milliseconds: 400));

  final double? initialPose;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    final pose = switch (progress) {
      0 => 0.0,
      < 0.5 => initialPose ?? 0.25,
      _ => 0.25,
    };
    transform
      ..blur(4)
      ..disintegrate(progress: pose, direction: const Offset(1, -0.6));
  }
}
