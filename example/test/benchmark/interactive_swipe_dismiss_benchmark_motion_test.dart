import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/interactive_swipe_dismiss/interactive_swipe_dismiss_benchmark_motion.dart';

void main() {
  group('InteractiveSwipeDismissBenchmarkMotion', () {
    test(
      'when the viewport is tall, it should cap primary travel at 120 pixels',
      () {
        const motion = InteractiveSwipeDismissBenchmarkMotion(
          origin: Offset.zero,
          viewportSize: Size(360, 800),
        );

        expect(motion.maximumPrimaryTravel, 120);
      },
    );

    test(
      'when the viewport is short, it should keep travel below dismissal',
      () {
        const motion = InteractiveSwipeDismissBenchmarkMotion(
          origin: Offset.zero,
          viewportSize: Size(320, 400),
        );

        expect(motion.maximumPrimaryTravel, lessThan(400 * 0.25));
      },
    );

    test(
      'when one cycle completes, it should repeat the exact pointer position',
      () {
        const motion = InteractiveSwipeDismissBenchmarkMotion(
          origin: Offset(50, 100),
          viewportSize: Size(360, 800),
        );

        expect(
          motion.positionForStep(
            InteractiveSwipeDismissBenchmarkMotion.framesPerCycle,
          ),
          motion.positionForStep(0),
        );
      },
    );

    test(
      'when the path advances, it should exercise free cross-axis movement',
      () {
        const motion = InteractiveSwipeDismissBenchmarkMotion(
          origin: Offset(50, 100),
          viewportSize: Size(360, 800),
        );

        final crossPositions = <double>{};
        for (var step = 0; step < 32; step += 1) {
          crossPositions.add(motion.positionForStep(step).dx);
        }

        expect(crossPositions.length, greaterThan(2));
      },
    );

    test(
      'when a negative step is requested, it should assert in debug mode',
      () {
        const motion = InteractiveSwipeDismissBenchmarkMotion(
          origin: Offset.zero,
          viewportSize: Size(360, 800),
        );

        expect(() => motion.positionForStep(-1), throwsAssertionError);
      },
    );
  });
}
