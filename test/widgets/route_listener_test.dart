import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'route_listener/route_listener_progress_animation.dart';
import 'route_listener/route_listener_progress_route.dart';

void main() {
  group('RouteListener', () {
    for (final initial in [0.0, 0.7, 1.0]) {
      testWidgets(
        'when mounted at progress $initial with only a progress callback, it should report the initial value after the frame',
        (tester) async {
          final values = <double>[];
          final animation = AnimationController(vsync: tester, value: initial);
          addTearDown(animation.dispose);
          final route = RouteListenerProgressRoute(
            progress: animation,
            builder: (_) => RouteListener(onProgressChanged: values.add, child: const SizedBox()),
          );
          await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
          await tester.pump();
          expect(values, [initial]);
        },
      );
    }

    testWidgets('when progress is delivered, it should run after the frame has finished', (tester) async {
      final phases = <SchedulerPhase>[];
      final animation = AnimationController(vsync: tester);
      addTearDown(animation.dispose);
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (_) => RouteListenerProgressRoute(
            progress: animation,
            builder: (_) => RouteListener(
              onProgressChanged: (_) => phases.add(SchedulerBinding.instance.schedulerPhase),
              child: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pump();
      animation.value = 0.6;
      await tester.pump();
      expect(phases, [SchedulerPhase.idle, SchedulerPhase.idle]);
    });

    testWidgets('when progress changes back to the delivered value within a frame, it should not repeat the callback', (
      tester,
    ) async {
      final values = <double>[];
      final animation = AnimationController(vsync: tester, value: 0.4);
      addTearDown(animation.dispose);
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (_) => RouteListenerProgressRoute(
            progress: animation,
            builder: (_) => RouteListener(onProgressChanged: values.add, child: const SizedBox()),
          ),
        ),
      );
      await tester.pump();
      animation
        ..value = 0.6
        ..value = 0.4;
      await tester.pump();
      expect(values, [0.4]);
    });

    testWidgets(
      'when progress observation is enabled then disabled, it should add and remove exactly one value listener',
      (tester) async {
        var enabled = false;
        late StateSetter rebuild;
        final animation = RouteListenerProgressAnimation(vsync: tester);
        addTearDown(animation.dispose);
        await tester.pumpWidget(
          MaterialApp(
            onGenerateRoute: (_) => RouteListenerProgressRoute(
              progress: animation,
              builder: (_) => StatefulBuilder(
                builder: (_, setState) {
                  rebuild = setState;
                  return RouteListener(
                    onSettled: () {},
                    onProgressChanged: enabled ? (_) {} : null,
                    child: const SizedBox(),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();
        final initialListeners = animation.listenerCount;
        rebuild(() => enabled = true);
        await tester.pump();
        final addedListeners = animation.listenerCount - initialListeners;
        rebuild(() => enabled = false);
        await tester.pump();
        expect((addedListeners, animation.listenerCount - initialListeners), (1, 0));
      },
    );

    testWidgets('when there is no enclosing route, it should report one after the frame', (tester) async {
      final values = <double>[];
      await tester.pumpWidget(RouteListener(onProgressChanged: values.add, child: const SizedBox()));
      await tester.pump();
      expect(values, [1.0]);
    });

    testWidgets(
      'when progress changes repeatedly in one frame and then reverses, it should report only each frame latest value',
      (tester) async {
        final values = <double>[];
        final animation = AnimationController(vsync: tester);
        addTearDown(animation.dispose);
        await tester.pumpWidget(
          MaterialApp(
            onGenerateRoute: (_) => RouteListenerProgressRoute(
              progress: animation,
              builder: (_) => RouteListener(onProgressChanged: values.add, child: const SizedBox()),
            ),
          ),
        );
        await tester.pump();
        animation
          ..value = 0.2
          ..value = 0.6
          ..value = 0.8;
        await tester.pump();
        animation.value = 0.4;
        await tester.pump();
        animation.value = 0.1;
        await tester.pump();
        animation.value = 0.1;
        await tester.pump();
        expect(values, [0.0, 0.8, 0.4, 0.1]);
      },
    );

    testWidgets('when progress jumps directly to completion, it should report the completed value', (tester) async {
      final values = <double>[];
      final animation = AnimationController(vsync: tester);
      addTearDown(animation.dispose);
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (_) => RouteListenerProgressRoute(
            progress: animation,
            builder: (_) => RouteListener(onProgressChanged: values.add, child: const SizedBox()),
          ),
        ),
      );
      await tester.pump();
      animation.value = 1;
      await tester.pump();
      expect(values, [0.0, 1.0]);
    });

    testWidgets('when progress changes, it should leave the child build count unchanged', (tester) async {
      var builds = 0;
      final animation = AnimationController(vsync: tester);
      addTearDown(animation.dispose);
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (_) => RouteListenerProgressRoute(
            progress: animation,
            builder: (_) => RouteListener(
              onProgressChanged: (_) {},
              child: Builder(
                builder: (_) {
                  builds++;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final initialBuilds = builds;
      animation.value = 0.6;
      await tester.pump();
      expect(builds, initialBuilds);
    });

    testWidgets('when a covering route enters and leaves, it should not report secondary progress', (tester) async {
      final values = <double>[];
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: RouteListener(
            onProgressChanged: values.add,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.push<void>(MaterialPageRoute(builder: (_) => const SizedBox()));
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(values, [1.0]);
    });

    testWidgets('when the callback is replaced, it should deliver subsequent changes without replaying progress', (
      tester,
    ) async {
      final first = <double>[];
      final second = <double>[];
      var callback = first.add;
      late StateSetter rebuild;
      final animation = AnimationController(vsync: tester, value: 0.4);
      addTearDown(animation.dispose);
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (_) => RouteListenerProgressRoute(
            progress: animation,
            builder: (_) => StatefulBuilder(
              builder: (_, setState) {
                rebuild = setState;
                return RouteListener(onProgressChanged: callback, child: const SizedBox());
              },
            ),
          ),
        ),
      );
      await tester.pump();
      rebuild(() => callback = second.add);
      await tester.pump();
      animation.value = 0.7;
      await tester.pump();
      expect(
        [first, second],
        [
          [0.4],
          [0.7],
        ],
      );
    });

    testWidgets('when progress observation is disabled then enabled, it should report the current value', (
      tester,
    ) async {
      final values = <double>[];
      var enabled = true;
      late StateSetter rebuild;
      final animation = AnimationController(vsync: tester, value: 0.4);
      addTearDown(animation.dispose);
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (_) => RouteListenerProgressRoute(
            progress: animation,
            builder: (_) => StatefulBuilder(
              builder: (_, setState) {
                rebuild = setState;
                return RouteListener(
                  onSettled: () {},
                  onProgressChanged: enabled ? values.add : null,
                  child: const SizedBox(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      animation.value = 0.5;
      rebuild(() => enabled = false);
      await tester.pump();
      animation.value = 0.8;
      await tester.pump();
      rebuild(() => enabled = true);
      await tester.pump();
      await tester.pump();
      expect(values, [0.4, 0.8]);
    });

    testWidgets('when the primary animation is replaced, it should observe the new animation and detach the old one', (
      tester,
    ) async {
      final values = <double>[];
      final first = AnimationController(vsync: tester, value: 0.2);
      final second = AnimationController(vsync: tester, value: 0.7);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      late StateSetter rebuild;
      final route = RouteListenerProgressRoute(
        progress: first,
        builder: (_) => StatefulBuilder(
          builder: (_, setState) {
            rebuild = setState;
            return RouteListener(onProgressChanged: values.add, child: const SizedBox());
          },
        ),
      );
      await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
      await tester.pump();
      rebuild(() => route.progress = second);
      await tester.pump();
      await tester.pump();
      first.value = 0.5;
      await tester.pump();
      second.value = 0.9;
      await tester.pump();
      expect(values, [0.2, 0.7, 0.9]);
    });

    testWidgets('when disposed with pending progress, it should suppress delivery and detach its listener', (
      tester,
    ) async {
      final values = <double>[];
      final animation = RouteListenerProgressAnimation(vsync: tester);
      addTearDown(animation.dispose);
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (_) => RouteListenerProgressRoute(
            progress: animation,
            builder: (_) => RouteListener(onProgressChanged: values.add, child: const SizedBox()),
          ),
        ),
      );
      await tester.pump();
      animation.value = 0.6;
      await tester.pumpWidget(const SizedBox());
      animation.value = 0.9;
      await tester.pump();
      expect(
        [values, animation.listenerCount],
        [
          [0.0],
          0,
        ],
      );
    });

    testWidgets('when mounted on a settled route, it should call onSettled once after the frame', (tester) async {
      var settledCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteListener(onSettled: () => settledCount++, child: const Text('Content')),
          ),
        ),
      );

      expect(settledCount, 0);
      await tester.pump();
      expect(settledCount, 1);
      await tester.pump();
      expect(settledCount, 1);
    });

    testWidgets('when a route enters and leaves, it should report each settled-state change once', (tester) async {
      var settledCount = 0;
      var unsettledCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (routeContext) => Scaffold(
                      body: RouteListener(
                        onSettled: () => settledCount++,
                        onUnsettled: () => unsettledCount++,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(routeContext).pop(),
                          child: const Text('Pop'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Push'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Push'));
      await tester.pump();
      expect(settledCount, 0);
      await tester.pumpAndSettle();
      expect(settledCount, 1);

      await tester.tap(find.text('Pop'));
      await tester.pumpAndSettle();
      expect(unsettledCount, 1);
      expect(settledCount, 1);
    });

    testWidgets('when a covering route leaves, it should wait for its exit before settling again', (tester) async {
      var settledCount = 0;
      var unsettledCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  RouteListener(
                    onSettled: () => settledCount++,
                    onUnsettled: () => unsettledCount++,
                    child: const Text('Content'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (routeContext) => Scaffold(
                          body: ElevatedButton(
                            onPressed: () => Navigator.of(routeContext).pop(),
                            child: const Text('Pop'),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('Push'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(settledCount, 1);

      await tester.tap(find.text('Push'));
      await tester.pumpAndSettle();
      expect(unsettledCount, 1);

      await tester.tap(find.text('Pop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(settledCount, 1);
      await tester.pumpAndSettle();
      expect(settledCount, 2);
    });

    testWidgets('when a navigation gesture is cancelled, it should report un-settle and re-settle', (tester) async {
      var settledCount = 0;
      var unsettledCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteListener(
              onSettled: () => settledCount++,
              onUnsettled: () => unsettledCount++,
              child: const Text('Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navigator = Navigator.of(tester.element(find.byType(RouteListener)))..didStartUserGesture();
      await tester.pump();
      expect(unsettledCount, 1);
      navigator.didStopUserGesture();
      await tester.pump();
      expect(settledCount, 2);
    });

    testWidgets('when route state changes twice in one frame, it should report both changes in order', (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteListener(
              onSettled: () => events.add('settled'),
              onUnsettled: () => events.add('unsettled'),
              child: const Text('Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(RouteListener)))
        ..didStartUserGesture()
        ..didStopUserGesture();
      await tester.pump();

      expect(events, ['settled', 'unsettled', 'settled']);
    });

    testWidgets('when no route encloses it, it should report settled once', (tester) async {
      var settledCount = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RouteListener(onSettled: () => settledCount++, child: const Text('Content')),
        ),
      );
      await tester.pump();
      expect(settledCount, 1);
    });

    testWidgets('when route state changes, it should not rebuild its child', (tester) async {
      var builds = 0;
      var settledCount = 0;
      final child = Builder(
        builder: (context) {
          builds++;
          return const Text('Content');
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteListener(onSettled: () => settledCount++, child: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final originalBuilds = builds;

      final navigator = Navigator.of(tester.element(find.byType(RouteListener)))..didStartUserGesture();
      await tester.pump();
      navigator.didStopUserGesture();
      await tester.pump();

      expect(settledCount, 2);
      expect(builds, originalBuilds);
    });

    testWidgets('when disposed, it should not call onUnsettled', (tester) async {
      var unsettledCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteListener(
              onSettled: () {},
              onUnsettled: () => unsettledCount++,
              child: const Text('Content'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());

      expect(unsettledCount, 0);
    });
  });
}
