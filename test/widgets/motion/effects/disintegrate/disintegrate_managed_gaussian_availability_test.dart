import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show ImageFilterLayer;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'disintegrate_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('when managed Gaussian is unavailable, it should send the sharp capture once per play', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1200, 1500);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final harness = DisintegrateTestHarness(tester, native: true, managedGaussianAvailable: false);
    for (final (size, sigma) in [
      (const Size(320, 320), 0.0),
      (const Size(120, 48), 2.0),
      (const Size(240, 100), 4.0),
      (const Size(320, 320), 2.0),
    ]) {
      await harness.mount(
        effect: _LargeBlurPulse(sigma),
        canvasSize: const Size(400, 500),
        child: ColoredBox(
          color: const Color(0x80603020),
          child: SizedBox.fromSize(size: size),
        ),
      );
      await harness.start();
      await tester.pump(const Duration(seconds: 1));
    }
    await harness.start();

    final preparations = harness.calls
        .where((call) => call.method == 'prepare')
        .map((call) => call.arguments! as Map<Object?, Object?>)
        .toList();
    expect(
      [
        harness.calls
            .where((call) => call.method == 'supportsManagedGaussian' || call.method == 'prepare')
            .map((call) => call.method)
            .toList(),
        preparations.map((arguments) => (arguments['frame']! as Float64List).length).toList(),
        tester.layers.whereType<ImageFilterLayer>().single.imageFilter,
      ],
      [
        ['prepare', 'prepare', 'supportsManagedGaussian', 'prepare', 'prepare', 'prepare'],
        [14, 14, 14, 14, 14],
        ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2, tileMode: .decal),
      ],
    );
  }, skip: ui.ImageFilter.isShaderFilterSupported);

  testWidgets('when Android Pie accepts the explicit legacy Gaussian route, it should use timestamp readiness', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(720, 1184);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final harness = DisintegrateTestHarness(
      tester,
      native: true,
      nativeGaussian: true,
      managedGaussianAvailable: false,
    );
    await harness.mount(
      effect: const _LargeBlurPulse(4),
      canvasSize: const Size(360, 450),
      child: const ColoredBox(color: Color(0x80603020), child: SizedBox(width: 240, height: 100)),
    );
    await harness.start();
    final arguments = harness.calls.singleWhere((call) => call.method == 'prepare').arguments! as Map<Object?, Object?>;
    expect(
      [
        arguments['legacyGaussian'],
        arguments['fullDensityGaussian'],
        (arguments['frame']! as Float64List).length,
        tester.getSize(find.byType(Texture)),
        harness.calls.where((call) => call.method == 'awaitFirstFrame').length,
        tester.layers.whereType<ImageFilterLayer>().length,
      ],
      [true, null, 16, const Size(336, 196), 1, 0],
    );
  }, skip: ui.ImageFilter.isShaderFilterSupported);

  testWidgets('when legacy blur stays below the reduced-grid threshold, it should keep the Flutter filter', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(720, 1184);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final harness = DisintegrateTestHarness(
      tester,
      native: true,
      nativeGaussian: true,
      managedGaussianAvailable: false,
    );
    await harness.mount(
      effect: const _LargeBlurPulse(2),
      canvasSize: const Size(360, 450),
      child: const ColoredBox(color: Color(0x80603020), child: SizedBox(width: 240, height: 100)),
    );
    await harness.start();
    final arguments = harness.calls.singleWhere((call) => call.method == 'prepare').arguments! as Map<Object?, Object?>;
    expect(
      [
        arguments['nativeGaussian'],
        (arguments['frame']! as Float64List).length,
        tester.layers.whereType<ImageFilterLayer>().single.imageFilter,
      ],
      [null, 14, ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2, tileMode: .decal)],
    );
  }, skip: ui.ImageFilter.isShaderFilterSupported);
}

class _LargeBlurPulse extends MotionEffect {
  const new(this.sigma);

  final double sigma;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..disintegrate(progress: 0.25, direction: const Offset(1, -0.6))
      ..blur(sigma);
  }
}
