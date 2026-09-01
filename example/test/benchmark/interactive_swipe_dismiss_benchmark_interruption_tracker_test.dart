import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/interactive_swipe_dismiss/interactive_swipe_dismiss_benchmark_interruption_tracker.dart';

void main() {
  group('InteractiveSwipeDismissBenchmarkInterruptionTracker', () {
    test(
      'when lifecycle changes during a measured window, '
      'it should invalidate the window',
      () {
        final tracker =
            InteractiveSwipeDismissBenchmarkInterruptionTracker(
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
      'when another view loses focus, it should keep the window valid',
      () {
        final tracker =
            InteractiveSwipeDismissBenchmarkInterruptionTracker(
                AppLifecycleState.resumed,
              )
              ..viewId = 7
              ..startWindow(collectFrames: true);
        final changed = tracker.updateViewFocus(
          const ViewFocusEvent(
            viewId: 8,
            state: ViewFocusState.unfocused,
            direction: ViewFocusDirection.undefined,
          ),
        );

        expect(
          <String, Object>{
            'changed': changed,
            'reasons': tracker.invalidReasons,
          },
          <String, Object>{'changed': false, 'reasons': <String>[]},
        );
      },
    );

    test(
      'when the benchmark view loses focus, it should invalidate the window',
      () {
        final tracker =
            InteractiveSwipeDismissBenchmarkInterruptionTracker(
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
      'when warmup is interrupted, it should not create an invalid trial',
      () {
        final tracker =
            InteractiveSwipeDismissBenchmarkInterruptionTracker(
                AppLifecycleState.resumed,
              )
              ..startWindow(collectFrames: false)
              ..updateLifecycle(AppLifecycleState.inactive);

        expect(tracker.invalidReasons, isEmpty);
      },
    );

    test(
      'when a measured window starts inactive, it should invalidate it',
      () {
        final tracker = InteractiveSwipeDismissBenchmarkInterruptionTracker(
          AppLifecycleState.inactive,
        )..startWindow(collectFrames: true);

        expect(
          tracker.invalidReasons,
          <String>['window_started_noninteractive'],
        );
      },
    );

    test(
      'when lifecycle and focus return, it should become interactive again',
      () {
        final tracker =
            InteractiveSwipeDismissBenchmarkInterruptionTracker(
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

    test(
      'when an ended window is interrupted, it should keep its result valid',
      () {
        final tracker =
            InteractiveSwipeDismissBenchmarkInterruptionTracker(
                AppLifecycleState.resumed,
              )
              ..startWindow(collectFrames: true)
              ..endWindow()
              ..updateLifecycle(AppLifecycleState.inactive);

        expect(tracker.invalidReasons, isEmpty);
      },
    );
  });
}
