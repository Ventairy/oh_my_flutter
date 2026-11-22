import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'motion/effects/disintegrate/disintegrate_test_harness.dart';

void main() {
  for (final sigma in [-1.0, double.infinity, double.nan]) {
    testWidgets('when sigma is $sigma, it should reject the configuration', (tester) async {
      await tester.pumpWidget(_Scene.wrap(Motion(effect: _BlurEffect(sigma), child: _Scene.tile)));
      expect(tester.takeException(), isAssertionError);
    });
  }

  testWidgets('when blur calls overlap, it should apply their combined variance after scaling', (tester) async {
    await tester.pumpWidget(
      _Scene.wrap(
        const Motion.list(
          startup: MotionStartup.hold,
          effects: [_ScaleAndFadeEffect(), _BlurEffect(3), _BlurEffect(4)],
          child: _Scene.tile,
        ),
      ),
    );
    final layer = tester.layers.whereType<ImageFilterLayer>().single;
    expect(
      (layer.imageFilter, layer.firstChild.runtimeType),
      (_Scene.filter(5), OpacityLayer),
    );
  });

  testWidgets('when a constant blur is rebuilt, it should reuse its layer and filter', (tester) async {
    final controller = MotionController();
    await tester.pumpWidget(
      _Scene.wrap(Motion(controller: controller, effect: const _BlurEffect(3), child: _Scene.tile)),
    );
    final layer = tester.layers.whereType<ImageFilterLayer>().single;
    final filter = layer.imageFilter;
    await tester.pump(const Duration(milliseconds: 100));
    final activeLayer = tester.layers.whereType<ImageFilterLayer>().single;
    expect((identical(activeLayer, layer), identical(activeLayer.imageFilter, filter)), (true, true));
  });

  testWidgets('when a reveal reaches zero sigma, it should remove the filter layer', (tester) async {
    await tester.pumpWidget(_Scene.wrap(const Motion(effect: _BlurEffect(4, reveal: true), child: _Scene.tile)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = tester.layers.whereType<ImageFilterLayer>().single.imageFilter;
    await tester.pump(const Duration(milliseconds: 100));
    expect((mid, tester.layers.whereType<ImageFilterLayer>().length), (_Scene.filter(2), 0));
  });

  testWidgets('when the child is invisible, it should skip the filter layer', (tester) async {
    await tester.pumpWidget(
      _Scene.wrap(
        const Motion.list(
          startup: MotionStartup.hold,
          effects: [_BlurEffect(4), FadeInMotionEffect()],
          child: _Scene.tile,
        ),
      ),
    );
    expect(tester.layers.whereType<ImageFilterLayer>(), isEmpty);
  });

  testWidgets('when blur extends beyond layout, it should paint a transparent halo', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      _Scene.wrap(
        const Motion(startup: MotionStartup.hold, effect: _BlurEffect(4), child: _Scene.tile),
        key: key,
      ),
    );
    final alpha = await _Scene.alphaAt(tester, key, 18, 40);
    expect(alpha, allOf(greaterThan(0), lessThan(255)));
  });

  testWidgets('when a later scale follows blur, it should scale the softened edges', (tester) async {
    await tester.pumpWidget(
      _Scene.wrap(
        const Motion.list(
          startup: MotionStartup.hold,
          effects: [_BlurEffect(5), _ScaleAndFadeEffect()],
          child: _Scene.tile,
        ),
      ),
    );
    expect(tester.layers.whereType<ImageFilterLayer>().single.imageFilter, _Scene.filter(4));
  });

  testWidgets('when a delayed blur follows rotation, it should start at its own progress', (tester) async {
    await tester.pumpWidget(
      _Scene.wrap(
        const Motion.list(
          effects: [RotateMotionEffect(degrees: 90), _DelayedBlur()],
          child: _Scene.tile,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final beforeDelay = tester.layers.whereType<ImageFilterLayer>().length;
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 50));
    final whileRotating = tester.layers.whereType<ImageFilterLayer>().single.imageFilter;
    expect((beforeDelay, whileRotating), (0, _Scene.filter(2)));
  });

  testWidgets('when blur precedes breakup, it should keep the blur inherited at breakup', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(effect: const _BlurBeforeBreakup(holdBlur: true));
    await harness.start();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 40));
    final held = await harness.pixels();
    await tester.pumpWidget(const SizedBox.shrink());
    await harness.mount(effect: const _BlurBeforeBreakup(holdBlur: false));
    await harness.start();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 40));
    expect(await harness.pixels(), held);
  });

  testWidgets('when breakup loops between rendered frames, it should capture the latest blur', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(
      effect: const _LoopingBreakup(),
      effects: const [_GrowingBlur(), _LoopingBreakup()],
    );
    await harness.start();
    await tester.pump(const Duration(milliseconds: 10));
    final firstCycle = await harness.pixels();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 20));
    expect(await harness.pixels(), isNot(firstCycle));
  });

  testWidgets('when blurred text breaks up, it should freeze each glyph at its staggered start', (tester) async {
    final harness = DisintegrateTestHarness(tester);

    Future<Uint8List> play({required bool holdBlur}) async {
      await tester.pumpWidget(
        _Scene.wrap(
          TextMotion(
            controller: harness.motionController,
            effect: _BlurBeforeBreakup(holdBlur: holdBlur),
            startup: MotionStartup.hold,
            stagger: const Duration(milliseconds: 20),
            child: const Text('AB', style: TextStyle(color: Color(0xFF215486), fontSize: 16)),
          ),
          key: harness.captureKey,
        ),
      );
      await harness.start();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 60));
      final pixels = await harness.pixels();
      await tester.pumpWidget(const SizedBox.shrink());
      return pixels;
    }

    expect(await play(holdBlur: false), await play(holdBlur: true));
  });

  testWidgets('when blur is moved after breakup, it should soften the gaps between moving pieces', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(effect: const _BlurBeforeBreakup(holdBlur: true));
    await harness.start();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 40));
    final blurredSource = await harness.pixels();
    await tester.pumpWidget(const SizedBox.shrink());
    await harness.mount(effect: const _BlurBeforeBreakup(holdBlur: true, blurFirst: false));
    await harness.start();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 40));
    final blurredParticles = await harness.pixels();
    await tester.pumpWidget(const SizedBox.shrink());
    await harness.mount(effect: const _BlurBeforeBreakup(holdBlur: true, sigma: 0));
    await harness.start();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 40));
    expect(blurredSource, allOf(isNot(blurredParticles), isNot(await harness.pixels())));
  });

  testWidgets('when blurred particles overlay the source, it should keep live edges sharp', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final harness = DisintegrateTestHarness(tester, native: true);
    await harness.mount(effect: const _ParticlePulse(), overlay: true);
    final before = await harness.pixels();
    await harness.start();
    await tester.pump(const Duration(milliseconds: 100));

    // The mock texture contributes no pixels, so this isolates the live source.
    expect(await harness.pixels(), before);
  });

  for (final native in [false, true]) {
    testWidgets('when particles pulse and replay with native=$native, it should restore the same blur', (tester) async {
      debugDefaultTargetPlatformOverride = native ? TargetPlatform.iOS : TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final harness = DisintegrateTestHarness(tester, native: native);
      await harness.mount(effect: const _ParticlePulse(), overlay: true);
      await harness.start();
      await tester.pump(const Duration(milliseconds: 100));
      final peak = tester.layers.whereType<ImageFilterLayer>().single.imageFilter;
      final showsTexture = find.byType(Texture).evaluate().isNotEmpty;
      await tester.pump(const Duration(milliseconds: 100));
      final filtersAtEnd = tester.layers.whereType<ImageFilterLayer>().length;
      await harness.start();
      await tester.pump(const Duration(milliseconds: 100));
      final replay = tester.layers.whereType<ImageFilterLayer>().single.imageFilter;
      expect((peak, showsTexture, filtersAtEnd, replay), (_Scene.filter(4), native, 0, _Scene.filter(4)));
    });
  }
}

abstract final class _Scene {
  static const tile = ColoredBox(
    color: Color(0xFF215486),
    child: SizedBox(width: 40, height: 40),
  );

  static Widget wrap(Widget child, {GlobalKey? key}) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: RepaintBoundary(
        key: key,
        child: SizedBox(width: 80, height: 80, child: Center(child: child)),
      ),
    ),
  );

  static ui.ImageFilter filter(double sigma) =>
      ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);

  static Future<int?> alphaAt(WidgetTester tester, GlobalKey key, int x, int y) {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        return (await image.toByteData())!.getUint8((y * image.width + x) * 4 + 3);
      } finally {
        image.dispose();
      }
    });
  }
}

class _BlurEffect extends MotionEffect {
  const new(this.sigma, {this.reveal = false}) : super(duration: const Duration(milliseconds: 200));

  final double sigma;
  final bool reveal;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.blur(reveal ? sigma * (1 - progress) : sigma);
  }
}

class _ScaleAndFadeEffect extends MotionEffect {
  const new();

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..scale(0.8)
      ..fade(0.6);
  }
}

class _ParticlePulse extends MotionEffect {
  const new() : super(duration: const Duration(milliseconds: 200));

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..disintegrate(progress: progress, direction: const Offset(1, 0))
      ..blur(16 * progress * (1 - progress));
  }
}

class _BlurBeforeBreakup extends MotionEffect {
  const new({required this.holdBlur, this.blurFirst = true, this.sigma = 4})
    : super(duration: const Duration(milliseconds: 200));

  final bool holdBlur;
  final bool blurFirst;
  final double sigma;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    final frameSigma = holdBlur || progress <= 0.5 ? sigma : 0.0;
    if (blurFirst) transform.blur(frameSigma);
    transform.disintegrate(progress: (progress - 0.35) / 0.65, direction: const Offset(1, 0));
    if (!blurFirst) transform.blur(frameSigma);
  }
}

class _DelayedBlur extends MotionEffect {
  const new() : super(delay: const Duration(milliseconds: 100), duration: const Duration(milliseconds: 100));

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.blur(4 * progress);
  }
}

class _GrowingBlur extends MotionEffect {
  const new() : super(duration: const Duration(milliseconds: 200));

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.blur(6 * progress);
  }
}

class _LoopingBreakup extends MotionEffect {
  const new() : super(duration: const Duration(milliseconds: 100), playback: MotionPlayback.loop);

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.disintegrate(progress: 0.05 + 0.9 * progress, direction: const Offset(1, 0));
  }
}
