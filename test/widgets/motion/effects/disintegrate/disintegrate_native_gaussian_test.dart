import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show ImageFilterLayer;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'disintegrate_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final supportsGaussian = ui.ImageFilter.isShaderFilterSupported;

  testWidgets('when Android declines native Gaussian, it should prepare the same sharp capture at its base bounds', (
    tester,
  ) async {
    final harness = _LargeParticleScene.setup(tester);
    await _LargeParticleScene.mount(harness);
    await harness.start();
    for (var attempt = 0; attempt < 10 && find.byType(Texture).evaluate().isEmpty; attempt++) {
      await harness.prepare();
    }

    final preparations = harness.calls
        .where((call) => call.method == 'prepare')
        .map((call) => call.arguments! as Map<Object?, Object?>)
        .toList();
    final gaussian = preparations.first;
    final stock = preparations.last;
    final initial = gaussian['frame']! as Float64List;
    final ratio = (stock['minimumCellSize']! as double) / MotionEffectTransform.defaultParticleSize;
    final fittedSigma = supportsGaussian ? 2 * (1 - 0.0034 * 2 + 0.0000034 * 2 * 2) : 2.0;

    expect(
      [
        preparations.length,
        supportsGaussian && harness.calls.any((call) => call.method == 'supportsManagedGaussian'),
        gaussian['nativeGaussian'],
        gaussian['skiaGaussian'] ?? false,
        initial.length,
        initial[0],
        initial[14],
        initial[15],
        (gaussian['viewportWidth']! as int) - (stock['viewportWidth']! as int),
        (gaussian['viewportHeight']! as int) - (stock['viewportHeight']! as int),
        stock.containsKey('nativeGaussian'),
        (stock['frame']! as Float64List).length,
        listEquals(gaussian['image']! as Uint8List, stock['image']! as Uint8List),
        find.byType(Texture).evaluate().length,
        tester.layers.whereType<ImageFilterLayer>().single.imageFilter,
      ],
      [
        2,
        false,
        true,
        !supportsGaussian,
        16,
        0.25,
        closeTo(fittedSigma * ratio, 0.000001),
        closeTo(fittedSigma * tester.view.devicePixelRatio, 0.000001),
        2 * (12 * ratio).ceil(),
        2 * (12 * ratio).ceil(),
        false,
        14,
        true,
        1,
        ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2, tileMode: .decal),
      ],
    );
  });

  testWidgets('when a negotiated Gaussian texture never arrives, it should release that handle and show atlas blur', (
    tester,
  ) async {
    final harness = _LargeParticleScene.setup(tester, nativeGaussian: true);
    await _LargeParticleScene.mount(harness);
    await harness.start();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1100)));
    await harness.prepare();

    final releases = harness.calls
        .where((call) => call.method == 'dispose')
        .map((call) => (call.arguments! as Map<Object?, Object?>)['handle']);
    expect(
      (
        releases.singleOrNull,
        find.byType(Texture).evaluate().isEmpty,
        tester.layers.whereType<ImageFilterLayer>().single.imageFilter,
      ),
      (1, true, ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2, tileMode: .decal)),
    );
  });

  testWidgets('when iOS accepts native Gaussian, it should present the padded texture and send blur with its pose', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final harness = _LargeParticleScene.setup(tester, nativeGaussian: true);
    await _LargeParticleScene.mount(harness);
    await harness.start();
    await tester.pump(const Duration(milliseconds: 60));
    await harness.prepare();

    final arguments = harness.calls.singleWhere((call) => call.method == 'prepare').arguments! as Map<Object?, Object?>;
    final initial = arguments['frame']! as Float64List;
    final update =
        (harness.calls.lastWhere((call) => call.method == 'setFrame').arguments! as Map<Object?, Object?>)['frame']!
            as Float64List;
    final textureFinder = find.byType(Texture);
    final texture = tester.widget<Texture>(textureFinder);
    final size = tester.getSize(textureFinder);
    final ratio = (arguments['minimumCellSize']! as double) / MotionEffectTransform.defaultParticleSize;

    expect(
      [
        arguments['nativeGaussian'],
        initial.length,
        update.length,
        update[0],
        update.last,
        texture.filterQuality,
        size.width,
        size.height,
        harness.calls.where((call) => call.method == 'awaitFirstFrame').length,
        tester.layers.whereType<ImageFilterLayer>().length,
      ],
      [
        true,
        16,
        16,
        0.25,
        greaterThan(initial.last),
        ui.FilterQuality.low,
        closeTo((arguments['viewportWidth']! as int) / ratio, 0.000001),
        closeTo((arguments['viewportHeight']! as int) / ratio, 0.000001),
        1,
        0,
      ],
    );
  }, skip: !supportsGaussian);

  testWidgets('when a full-density Android blur reaches the smaller grid, it should request managed Gaussian output', (
    tester,
  ) async {
    final harness = _LargeParticleScene.setup(tester, nativeGaussian: true);
    await _LargeParticleScene.mount(harness, size: const Size(240, 100));
    await harness.start();

    final arguments = harness.calls.singleWhere((call) => call.method == 'prepare').arguments! as Map<Object?, Object?>;
    final frame = arguments['frame']! as Float64List;
    expect(
      [
        arguments['fullDensityGaussian'],
        arguments['legacyGaussian'],
        arguments['viewportWidth'],
        arguments['viewportHeight'],
        frame.length,
        frame[frame.length - 2],
        frame.last,
      ],
      [true, null, 1008, 588, 16, 6.0, 6.0],
    );
  }, skip: ui.ImageFilter.isShaderFilterSupported);

  testWidgets('when the platform omits full-density Gaussian acknowledgement, it should keep the Flutter filter', (
    tester,
  ) async {
    final harness = _LargeParticleScene.setup(
      tester,
      nativeGaussian: true,
      acknowledgeFullDensityGaussian: false,
    );
    await _LargeParticleScene.mount(harness, size: const Size(240, 100));
    await harness.start();

    final preparations = harness.calls
        .where((call) => call.method == 'prepare')
        .map((call) => call.arguments! as Map<Object?, Object?>);
    expect(
      [
        preparations.map((arguments) => arguments['fullDensityGaussian']).toList(),
        tester.layers.whereType<ImageFilterLayer>().single.imageFilter,
      ],
      [
        [true, null],
        ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2, tileMode: .decal),
      ],
    );
  }, skip: ui.ImageFilter.isShaderFilterSupported);
}

abstract final class _LargeParticleScene {
  static DisintegrateTestHarness setup(
    WidgetTester tester, {
    bool nativeGaussian = false,
    bool acknowledgeFullDensityGaussian = true,
  }) {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1200, 1500);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    return DisintegrateTestHarness(
      tester,
      native: true,
      nativeGaussian: nativeGaussian,
      acknowledgeFullDensityGaussian: acknowledgeFullDensityGaussian,
    );
  }

  static Future<void> mount(DisintegrateTestHarness harness, {Size size = const Size(320, 320)}) => harness.mount(
    effect: const _LargeParticleBlur(),
    canvasSize: const Size(400, 500),
    child: ColoredBox(
      color: const Color(0x80603020),
      child: SizedBox.fromSize(size: size),
    ),
  );
}

class _LargeParticleBlur extends MotionEffect {
  const new();

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..disintegrate(progress: 0.25, direction: const Offset(1, -0.6))
      ..blur(2 + 2 * progress);
  }
}
