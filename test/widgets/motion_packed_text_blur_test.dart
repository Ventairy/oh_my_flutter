import 'dart:ui' as ui;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Future<void> main() async {
  testWidgets('when a glyph is barely blurred on first playback, it should use a bounded tap layer', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MotionController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: TextMotion(
            controller: controller,
            startup: MotionStartup.hold,
            stagger: const Duration(milliseconds: 20),
            effect: const _StaggeredReveal(),
            child: const Text('ABCD', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final motion = tester.renderObject(find.byType(TextMotion));

    expect(motion, paintsExactlyCountTimes(#saveLayer, 1));
  });

  Future<RenderObject> warmShader(WidgetTester tester, MotionController controller) async {
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() => ui.FragmentProgram.fromAsset('shaders/motion_glyph_blur.frag'));
    final motion = tester.renderObject(find.byType(TextMotion));
    for (var attempt = 0; attempt < 200 && !motion.toStringDeep().contains('glyph blur shader warmed'); attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 10));
    }
    return motion;
  }

  for (final (label, fileName, milliseconds) in [
    ('mid-reveal', 'motion_packed_text_blur', 190),
    ('near sharp', 'motion_packed_text_blur_near_sharp', 285),
  ]) {
    final controller = MotionController();
    late ValueNotifier<bool> tickers;
    await goldenTest(
      'when many glyphs have different blur strengths at $label, it should preserve color and placement',
      fileName: fileName,
      constraints: const BoxConstraints.tightFor(width: 304, height: 158),
      builder: () {
        tickers = ValueNotifier(true);
        addTearDown(tickers.dispose);
        return Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: const Color(0xFFF5F5F0),
            child: SizedBox.expand(
              child: ValueListenableBuilder<bool>(
                valueListenable: tickers,
                builder: (context, enabled, child) => TickerMode(enabled: enabled, child: child!),
                child: Center(
                  child: SizedBox(
                    width: 240,
                    child: TextMotion(
                      controller: controller,
                      startup: MotionStartup.hold,
                      stagger: const Duration(milliseconds: 7),
                      effect: const _StaggeredReveal(),
                      child: const Text(
                        'Different edges come into focus',
                        style: TextStyle(fontSize: 18, color: Color(0xFF194973)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      whilePerforming: (tester) async {
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pump();
        final motion = await warmShader(tester, controller);
        controller.play();
        await tester.pump();
        await tester.pump(Duration(milliseconds: milliseconds));
        tickers.value = false;
        await tester.pump();
        await tester.pump();
        expect(motion.toStringDeep(), contains('glyph blur shader was used'));
        return null;
      },
    );
  }

  testWidgets('when adjacent glyphs share a wide blur, it should draw them in one filtered batch', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MotionController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: TextMotion(
            controller: controller,
            startup: MotionStartup.hold,
            stagger: const Duration(milliseconds: 4),
            effect: const _StaggeredReveal(rotation: 0),
            child: const Text('Different edges come into focus', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
    final motion = await warmShader(tester, controller);
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 17));

    expect(motion, paintsExactlyCountTimes(#drawRawAtlas, 1));
  });

  testWidgets('when one glyph remains blurred, it should use the warmed shader', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MotionController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: TextMotion(
            controller: controller,
            startup: MotionStartup.hold,
            stagger: const Duration(milliseconds: 20),
            effect: const _StaggeredReveal(),
            child: const Text('ABCD', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
    final motion = await warmShader(tester, controller);
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(motion.toStringDeep(), contains('glyph blur shader was used'));
  });

  testWidgets('when many glyphs exceed the shader radius, it should use the engine blur', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MotionController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: TextMotion(
            controller: controller,
            startup: MotionStartup.hold,
            stagger: const Duration(milliseconds: 7),
            effect: const _StaggeredReveal(minimumSigma: 12),
            child: const Text('Large staggered blur', style: TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
    final motion = await warmShader(tester, controller);
    controller.play();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final diagnostics = motion.toStringDeep();

    expect(
      (diagnostics.contains('glyph blur shader warmed'), diagnostics.contains('glyph blur shader was used')),
      (true, false),
    );
  });
}

class _StaggeredReveal extends MotionEffect {
  const new({this.minimumSigma = 0, this.rotation = 5});

  final double minimumSigma;
  final double rotation;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..fade(0.3 + 0.7 * progress)
      ..rotate(rotation * (1 - progress))
      ..blur(minimumSigma + 4 * (1 - progress));
  }
}
