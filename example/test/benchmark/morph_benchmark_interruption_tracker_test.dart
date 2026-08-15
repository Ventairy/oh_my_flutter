import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/morph/morph_benchmark_interruption_tracker.dart';

void main() {
  group('MorphBenchmarkInterruptionTracker', () {
    test(
      'when lifecycle changes during an attributed window, '
      'it should invalidate the window',
      () {
        final tracker =
            MorphBenchmarkInterruptionTracker(
                AppLifecycleState.resumed,
              )
              ..startWindow(collectFrames: true)
              ..updateLifecycle(AppLifecycleState.inactive);

        expect(
          tracker.invalidReasons,
          <String>['app_lifecycle:resumed->inactive'],
        );
      },
    );

    test(
      'when another view loses focus, '
      'it should keep the benchmark window valid',
      () {
        final tracker =
            MorphBenchmarkInterruptionTracker(
                AppLifecycleState.resumed,
              )
              ..viewId = 7
              ..startWindow(collectFrames: true)
              ..updateViewFocus(
                const ViewFocusEvent(
                  viewId: 8,
                  state: ViewFocusState.unfocused,
                  direction: ViewFocusDirection.undefined,
                ),
              );

        expect(tracker.invalidReasons, isEmpty);
      },
    );

    test(
      'when the benchmark view loses focus during an attributed window, '
      'it should invalidate the window',
      () {
        final tracker =
            MorphBenchmarkInterruptionTracker(
                AppLifecycleState.resumed,
              )
              ..viewId = 7
              ..startWindow(collectFrames: true)
              ..updateViewFocus(
                const ViewFocusEvent(
                  viewId: 7,
                  state: ViewFocusState.unfocused,
                  direction: ViewFocusDirection.undefined,
                ),
              );

        expect(
          tracker.invalidReasons,
          <String>['view_focus:unknown->unfocused'],
        );
      },
    );

    test(
      'when lifecycle changes outside a collected window, '
      'it should not invalidate a later window',
      () {
        final tracker =
            MorphBenchmarkInterruptionTracker(
                AppLifecycleState.resumed,
              )
              ..updateLifecycle(AppLifecycleState.inactive)
              ..updateLifecycle(AppLifecycleState.resumed)
              ..startWindow(collectFrames: true);

        expect(tracker.invalidReasons, isEmpty);
      },
    );

    test(
      'when an unmeasured transition is interrupted, '
      'it should not create an invalid trial',
      () {
        final tracker =
            MorphBenchmarkInterruptionTracker(
                AppLifecycleState.resumed,
              )
              ..startWindow(collectFrames: false)
              ..updateLifecycle(AppLifecycleState.inactive);

        expect(tracker.invalidReasons, isEmpty);
      },
    );

    test(
      'when an attributed window starts while inactive, '
      'it should invalidate the window',
      () {
        final tracker = MorphBenchmarkInterruptionTracker(
          AppLifecycleState.inactive,
        )..startWindow(collectFrames: true);

        expect(
          tracker.invalidReasons,
          <String>['window_started_noninteractive'],
        );
      },
    );

    test(
      'when lifecycle and focus return, '
      'it should become interactive again',
      () {
        final tracker =
            MorphBenchmarkInterruptionTracker(
                AppLifecycleState.resumed,
              )
              ..viewId = 7
              ..updateLifecycle(AppLifecycleState.inactive)
              ..updateViewFocus(
                const ViewFocusEvent(
                  viewId: 7,
                  state: ViewFocusState.unfocused,
                  direction: ViewFocusDirection.undefined,
                ),
              )
              ..updateLifecycle(AppLifecycleState.resumed)
              ..updateViewFocus(
                const ViewFocusEvent(
                  viewId: 7,
                  state: ViewFocusState.focused,
                  direction: ViewFocusDirection.forward,
                ),
              );

        expect(tracker.isInteractive, isTrue);
      },
    );
  });
}
