import 'package:alchemist/alchemist.dart';
// Alchemist's theme configuration uses Flutter's original Material type.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' show ThemeData;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'motion/effects/disintegrate/disintegrate_test_harness.dart';

Future<void> main() async {
  final config = AlchemistConfig.current();
  // Alchemist's text-blocking capture bypasses the retained filter layers.
  await AlchemistConfig.runWithConfig(
    config: config.copyWith(
      ciGoldensConfig: config.ciGoldensConfig.copyWith(obscureText: false, theme: ThemeData(fontFamily: 'Ahem')),
    ),
    run: _testBlurFrames,
  );
}

Future<void> _testBlurFrames() async {
  for (final (name, elapsed) in [
    ('sharp', Duration.zero),
    ('peak', const Duration(milliseconds: 200)),
    ('recovery', const Duration(milliseconds: 800)),
  ]) {
    final controller = MotionController();
    late ValueNotifier<bool> tickers;
    await goldenTest(
      'when motion reaches the $name frame, it should paint the corresponding blur',
      fileName: 'motion_blur_$name',
      constraints: const BoxConstraints.tightFor(width: 240, height: 220),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Motion(
                      controller: controller,
                      startup: MotionStartup.hold,
                      effect: const _Pulse(),
                      child: const ColoredBox(color: Color(0xFF204C70), child: SizedBox(width: 120, height: 34)),
                    ),
                    TextMotion(
                      controller: controller,
                      startup: MotionStartup.hold,
                      stagger: const Duration(milliseconds: 100),
                      effect: const _Pulse(),
                      child: const Text('FOCUS', style: TextStyle(fontSize: 28, color: Color(0xFF204C70))),
                    ),
                    TextMotion(
                      controller: controller,
                      startup: MotionStartup.hold,
                      stagger: const Duration(milliseconds: 70),
                      effect: const _Pulse(particles: true),
                      child: const Text('FOCUS', style: TextStyle(fontSize: 28, color: Color(0xFF285625))),
                    ),
                    Motion(
                      controller: controller,
                      startup: MotionStartup.hold,
                      effect: const _Pulse(particles: true),
                      child: const ColoredBox(color: Color(0xFF285625), child: SizedBox(width: 120, height: 34)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      whilePerforming: (tester) async {
        final harness = DisintegrateTestHarness(tester);
        controller.play();
        await harness.prepare();
        await tester.pump(elapsed);
        tickers.value = false;
        await tester.pump();
        return null;
      },
    );
  }
}

class _Pulse extends MotionEffect {
  const new({this.particles = false}) : super(duration: const Duration(milliseconds: 400));

  final bool particles;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    if (particles) {
      transform.disintegrate(
        progress: progress * 0.45,
        direction: const Offset(1, -0.25),
      );
    }
    transform.blur(20 * progress * (1 - progress));
  }
}
