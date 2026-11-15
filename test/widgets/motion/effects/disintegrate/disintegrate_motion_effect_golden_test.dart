import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'composed_disintegrate_effect.dart';
import 'disintegrate_test_harness.dart';

Future<void> main() async {
  for (final scenario in [
    (
      name: 'stationary',
      effect: const DisintegrateMotionEffect(direction: Offset.zero, duration: Duration(seconds: 2)),
    ),
    (name: 'scaled', effect: const ComposedDisintegrateEffect()),
    (name: 'two_stages', effect: const ComposedDisintegrateEffect(secondStage: true)),
  ]) {
    final motionController = MotionController();
    late ValueNotifier<bool> tickers;
    await goldenTest(
      'when ${scenario.name} disintegration is composed, it should preserve the captured colors',
      fileName: 'disintegrate_${scenario.name}',
      constraints: const BoxConstraints.tightFor(width: 240, height: 180),
      builder: () {
        tickers = ValueNotifier(true);
        addTearDown(tickers.dispose);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: ThemeData.light().colorScheme.surface,
            body: ValueListenableBuilder<bool>(
              valueListenable: tickers,
              builder: (context, enabled, child) => TickerMode(enabled: enabled, child: child!),
              child: Center(
                child: Motion(
                  controller: motionController,
                  startup: .hold,
                  effect: scenario.effect,
                  child: SizedBox(
                    width: 120,
                    height: 80,
                    child: Row(
                      children: [
                        Expanded(
                          child: ColoredBox(
                            color: ThemeData.light().colorScheme.primary,
                            child: const SizedBox.expand(),
                          ),
                        ),
                        Expanded(
                          child: ColoredBox(
                            color: ThemeData.light().colorScheme.tertiary,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      whilePerforming: (tester) async {
        final harness = DisintegrateTestHarness(tester);
        motionController.play();
        await harness.prepare();
        await tester.pump(const Duration(milliseconds: 700));
        tickers.value = false;
        await tester.pump();
        return null;
      },
    );
  }
}
