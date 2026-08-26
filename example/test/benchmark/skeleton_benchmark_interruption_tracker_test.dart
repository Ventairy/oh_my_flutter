import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/skeleton/skeleton_benchmark_interruption_tracker.dart';

void main() {
  group('SkeletonBenchmarkInterruptionTracker', () {
    test(
      'when lifecycle changes during a collected window, '
      'it should invalidate the window',
      () {
        final tracker =
            SkeletonBenchmarkInterruptionTracker(
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
      'it should keep the collected window valid',
      () {
        final tracker =
            SkeletonBenchmarkInterruptionTracker(
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
            'invalid_reasons': tracker.invalidReasons,
          },
          <String, Object>{
            'changed': false,
            'invalid_reasons': <String>[],
          },
        );
      },
    );

    test(
      'when the benchmark view loses focus during a collected window, '
      'it should invalidate the window',
      () {
        final tracker =
            SkeletonBenchmarkInterruptionTracker(
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
            SkeletonBenchmarkInterruptionTracker(
                AppLifecycleState.resumed,
              )
              ..updateLifecycle(AppLifecycleState.inactive)
              ..updateLifecycle(AppLifecycleState.resumed)
              ..startWindow(collectFrames: true);

        expect(tracker.invalidReasons, isEmpty);
      },
    );

    test(
      'when an uncollected window is interrupted, '
      'it should not create an invalid trial',
      () {
        final tracker =
            SkeletonBenchmarkInterruptionTracker(
                AppLifecycleState.resumed,
              )
              ..startWindow(collectFrames: false)
              ..updateLifecycle(AppLifecycleState.inactive);

        expect(tracker.invalidReasons, isEmpty);
      },
    );

    test(
      'when a collected window starts while inactive, '
      'it should invalidate the window',
      () {
        final tracker = SkeletonBenchmarkInterruptionTracker(
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
            SkeletonBenchmarkInterruptionTracker(
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
      'when an ended window is interrupted, '
      'it should keep its completed result valid',
      () {
        final tracker =
            SkeletonBenchmarkInterruptionTracker(
                AppLifecycleState.resumed,
              )
              ..startWindow(collectFrames: true)
              ..endWindow()
              ..updateLifecycle(AppLifecycleState.inactive);

        expect(tracker.invalidReasons, isEmpty);
      },
    );

    test(
      'when lifecycle state is repeated, '
      'it should not add a duplicate invalid reason',
      () {
        final tracker =
            SkeletonBenchmarkInterruptionTracker(
                AppLifecycleState.resumed,
              )
              ..startWindow(collectFrames: true)
              ..updateLifecycle(AppLifecycleState.inactive);
        final changed = tracker.updateLifecycle(AppLifecycleState.inactive);

        expect(
          <String, Object>{
            'changed': changed,
            'invalid_reasons': tracker.invalidReasons,
          },
          <String, Object>{
            'changed': false,
            'invalid_reasons': <String>[
              'app_lifecycle:resumed->inactive',
            ],
          },
        );
      },
    );
  });
}
