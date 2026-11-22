import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'disintegrate_test_harness.dart';
import 'two_blurred_breakups_effect.dart';

void main() {
  testWidgets('when blur follows breakup, it should keep transparent halo out of the native texture', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = DisintegrateTestHarness(tester, native: true);
    await harness.mount(effect: const _ParticleBlur(), child: const SizedBox(width: 120, height: 80));
    await harness.start();

    final arguments = harness.calls.singleWhere((call) => call.method == 'prepare').arguments! as Map<Object?, Object?>;
    expect((arguments['viewportWidth'], arguments['viewportHeight']), (360, 240));
  });

  testWidgets('when particles are blurred past their texture, it should paint the halo', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(
      effect: const _ParticleBlur(),
      child: const ColoredBox(color: Color(0xFFFFFFFF), child: SizedBox(width: 120, height: 80)),
    );
    await harness.start();

    final pixels = await harness.pixels();
    expect(pixels[(90 * 240 + 56) * 4 + 3], greaterThan(0));
  });

  testWidgets('when a blurred source is still intact, it should paint without tile seams', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(
      effect: const _BlurBeforeBreakup(),
      canvasSize: const Size(660, 500),
      child: const SizedBox(
        width: 540,
        height: 380,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xA00072B8), Color(0xFF0B3765), Color(0xFFB26902)]),
            borderRadius: BorderRadius.all(Radius.circular(15)),
          ),
        ),
      ),
    );
    await harness.start();
    await tester.pump(const Duration(milliseconds: 16));

    final pixels = await harness.pixels();
    expect(pixels[(250 * 660 + 370) * 4 + 3], greaterThanOrEqualTo(253));
  });

  testWidgets('when a blurred widget starts breaking up at 2× density, it should keep its far halo', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(
      effect: const _BlurBeforeBreakup(),
      child: const ColoredBox(color: Color(0xFFFFFFFF), child: SizedBox(width: 120, height: 80)),
    );
    await harness.start();
    await tester.pump(const Duration(milliseconds: 40));

    final pixels = await harness.pixels();
    expect(pixels[(90 * 240 + 183) * 4 + 3], greaterThan(12));
  });

  testWidgets('when two blurred breakups use different particle sizes, it should paint both stages', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(effect: const TwoBlurredBreakupsEffect());
    await harness.start();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });

  testWidgets('when the source changes before replay, it should capture the new color with blur', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    final color = ValueNotifier(const Color(0xFFFF0000));
    addTearDown(color.dispose);
    await harness.mount(
      effect: const _BlurBeforeBreakup(),
      child: ValueListenableBuilder<Color>(
        valueListenable: color,
        builder: (context, value, child) => ColoredBox(color: value, child: child),
        child: const SizedBox(width: 120, height: 80),
      ),
    );
    await harness.start();
    await tester.pump(const Duration(milliseconds: 100));
    color.value = const Color(0xFF0000FF);
    await tester.pump();
    await harness.start();
    await tester.pump(const Duration(milliseconds: 100));

    final pixels = await harness.pixels();
    var red = 0;
    var blue = 0;
    for (var index = 0; index < pixels.length; index += 4) {
      red += pixels[index];
      blue += pixels[index + 2];
    }
    expect(blue, greaterThan(red));
  });
}

class _ParticleBlur extends MotionEffect {
  const new();

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..disintegrate(progress: 0, direction: Offset.zero)
      ..blur(12);
  }
}

class _BlurBeforeBreakup extends MotionEffect {
  const new();

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..blur(4 + 0.5 * progress)
      ..disintegrate(progress: (progress - 0.12) / 0.88, direction: const Offset(1, -0.6));
  }
}
