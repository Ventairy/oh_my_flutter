import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'disintegrate_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('when a small Android Skia pulse can resize at 2×, it should request managed Gaussian output', (
    tester,
  ) async {
    final preparations = await _SmallManagedGaussianFixture.prepare(tester);
    expect(preparations.map(_SmallManagedGaussianFixture.configuration).toList(), [
      (true, true, null, true, 672, 392, 16, 8.0),
    ]);
  }, skip: ui.ImageFilter.isShaderFilterSupported);

  testWidgets('when managed 2× Gaussian acknowledgement is missing, it should prepare the sharp texture', (
    tester,
  ) async {
    final preparations = await _SmallManagedGaussianFixture.prepare(tester, acknowledge: false);
    expect(
      [
        preparations.map(_SmallManagedGaussianFixture.configuration).toList(),
        listEquals(preparations.first['image']! as Uint8List, preparations.last['image']! as Uint8List),
      ],
      [
        [(true, true, null, true, 672, 392, 16, 8.0), (null, null, null, null, 624, 344, 14, null)],
        true,
      ],
    );
  }, skip: ui.ImageFilter.isShaderFilterSupported);

  testWidgets('when a managed 2× pulse cannot reach the smaller grid, it should keep the Flutter filter', (
    tester,
  ) async {
    final preparations = await _SmallManagedGaussianFixture.prepare(tester, sigma: 2);
    expect(preparations.map(_SmallManagedGaussianFixture.configuration).toList(), [
      (null, null, null, null, 624, 344, 14, null),
    ]);
  }, skip: ui.ImageFilter.isShaderFilterSupported);

  testWidgets('when the managed probe row exceeds the small viewport cap, it should keep the Flutter filter', (
    tester,
  ) async {
    final preparations = await _SmallManagedGaussianFixture.prepare(tester, size: const Size(178, 242));
    expect(preparations.map(_SmallManagedGaussianFixture.configuration).toList(), [
      (null, null, null, null, 464, 592, 14, null),
    ]);
  }, skip: ui.ImageFilter.isShaderFilterSupported);

  testWidgets('when the managed probe row exceeds the texture height cap, it should keep the Flutter filter', (
    tester,
  ) async {
    final preparations = await _SmallManagedGaussianFixture.prepare(tester, size: const Size(28, 990));
    expect(preparations.map(_SmallManagedGaussianFixture.configuration).toList(), [
      (null, null, null, null, 76, 2000, 14, null),
    ]);
  }, skip: ui.ImageFilter.isShaderFilterSupported);
}

abstract final class _SmallManagedGaussianFixture {
  static Future<List<Map<Object?, Object?>>> prepare(
    WidgetTester tester, {
    double sigma = 4,
    Size size = const Size(240, 100),
    bool acknowledge = true,
  }) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1080, 2256);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final harness = DisintegrateTestHarness(
      tester,
      native: true,
      nativeGaussian: true,
      acknowledgeFullDensityGaussian: acknowledge,
    );
    await harness.mount(
      effect: _SmallBlurPulse(sigma),
      canvasSize: size.height > 450 ? Size(360, size.height) : const Size(360, 450),
      child: ColoredBox(
        color: const Color(0x80603020),
        child: SizedBox.fromSize(size: size),
      ),
    );
    await harness.start();
    return [
      for (final call in harness.calls)
        if (call.method == 'prepare') call.arguments! as Map<Object?, Object?>,
    ];
  }

  static (Object?, Object?, Object?, Object?, Object?, Object?, int, double?) configuration(
    Map<Object?, Object?> arguments,
  ) {
    final frame = arguments['frame']! as Float64List;
    return (
      arguments['nativeGaussian'],
      arguments['skiaGaussian'],
      arguments['legacyGaussian'],
      arguments['fullDensityGaussian'],
      arguments['viewportWidth'],
      arguments['viewportHeight'],
      frame.length,
      frame.length == 16 ? frame[14] : null,
    );
  }
}

class _SmallBlurPulse extends MotionEffect {
  const new(this.sigma);

  final double sigma;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..disintegrate(progress: 0.25, direction: const Offset(1, -0.6))
      ..blur(sigma);
  }
}
