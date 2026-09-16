import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'morph_navigator_observer/_morph_navigation_scenario.dart';
part 'morph_navigator_observer/_recording_navigation_flight_delegate.dart';

void main() {
  group('MorphNavigatorObserver', () {
    test('when no navigation has started, it should expose idle', () {
      expect(MorphNavigatorObserver().tagStatus('surface').value, MorphTagStatus.idle);
    });

    test('when equal tags are queried, it should reuse the live listenable', () {
      final observer = MorphNavigatorObserver();
      expect(identical(observer.tagStatus('surface'), observer.tagStatus('surface')), isTrue);
    });

    testWidgets('when its Navigator is queried, it should return the installed observer', (tester) async {
      final scenario = _MorphNavigationScenario();
      await tester.pumpWidget(scenario.app);
      expect(MorphNavigatorObserver.maybeOfNavigator(scenario.navigator.currentState!), scenario.observer);
    });

    testWidgets('when a Navigator has no observer, it should return null from optional lookup', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: const SizedBox()));
      expect(MorphNavigatorObserver.maybeOfNavigator(navigator.currentState!), isNull);
    });

    testWidgets('when a route starts, it should expose pending before destination layout', (tester) async {
      final scenario = _MorphNavigationScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      expect(scenario.observer.tagStatus('surface').value, MorphTagStatus.pending);
    });

    testWidgets('when a matched route finishes, it should report its accepted lifecycle', (tester) async {
      final scenario = _MorphNavigationScenario(duration: const Duration(milliseconds: 300));
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      final status = scenario.observer.tagStatus('surface');
      final values = <MorphTagStatus>[];
      void record() => values.add(status.value);
      status.addListener(record);
      addTearDown(() => status.removeListener(record));
      scenario.push(scenario.b);
      await tester.pumpAndSettle();
      expect(values, [MorphTagStatus.pending, MorphTagStatus.flying, MorphTagStatus.completed]);
    });

    testWidgets('when no endpoint uses a queried tag, it should resolve unmatched', (tester) async {
      final scenario = _MorphNavigationScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      final status = scenario.observer.tagStatus('missing');
      scenario.push(scenario.b);
      await tester.pumpAndSettle();
      expect(status.value, MorphTagStatus.unmatched);
    });

    testWidgets('when no Morph is mounted, it should still finish resolution', (tester) async {
      final observer = MorphNavigatorObserver();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, navigatorObservers: [observer], home: const SizedBox()),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.push<void>(MaterialPageRoute(builder: (_) => const SizedBox()));
      await tester.pumpAndSettle();
      expect(observer.tagStatus('missing').value, MorphTagStatus.unmatched);
    });

    testWidgets('when the previous route has no matching surface, it should expose unmatched', (tester) async {
      final scenario = _MorphNavigationScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(null);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pumpAndSettle();
      expect(scenario.observer.tagStatus('surface').value, MorphTagStatus.unmatched);
    });

    testWidgets('when a flight returns, it should complete the new navigation', (tester) async {
      final scenario = _MorphNavigationScenario(duration: const Duration(milliseconds: 300));
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pumpAndSettle();
      scenario.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(scenario.observer.tagStatus('surface').value, MorphTagStatus.completed);
    });

    testWidgets('when a push reverses before landing, it should complete the return', (tester) async {
      final scenario = _MorphNavigationScenario(duration: const Duration(milliseconds: 300));
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      scenario.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(scenario.observer.tagStatus('surface').value, MorphTagStatus.completed);
    });

    testWidgets('when an unrelated push interrupts a flight, it should expose only the latest result', (tester) async {
      final scenario = _MorphNavigationScenario(duration: const Duration(milliseconds: 300));
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      scenario.push(null);
      await tester.pumpAndSettle();
      expect(scenario.observer.tagStatus('surface').value, MorphTagStatus.unmatched);
    });

    testWidgets('when an accepted flight has zero duration, it should expose completed', (tester) async {
      final scenario = _MorphNavigationScenario(duration: Duration.zero);
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pumpAndSettle();
      expect(scenario.observer.tagStatus('surface').value, MorphTagStatus.completed);
    });

    testWidgets('when an active flight loses its destination, it should expose cancelled', (tester) async {
      final scenario = _MorphNavigationScenario(duration: const Duration(milliseconds: 300));
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      scenario.appearances[scenario.b]!.value = [];
      await tester.pumpAndSettle();
      expect(scenario.observer.tagStatus('surface').value, MorphTagStatus.cancelled);
    });

    testWidgets('when delegate types are incompatible, it should expose unmatched', (tester) async {
      final scenario = _MorphNavigationScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => Center(
            child: Morph(target: scenario.b, child: const SizedBox.square(dimension: 100)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (
          scenario.observer.tagStatus('surface').value,
          tester.takeException().toString().contains('endpoint delegate types are incompatible'),
        ),
        (MorphTagStatus.unmatched, true),
      );
    });

    testWidgets('when destination geometry is empty, it should expose unmatched', (tester) async {
      final scenario = _MorphNavigationScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => Center(
            child: Morph(
              target: scenario.b,
              flightConfig: MorphFlightConfig.custom(scenario.delegate),
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (
          scenario.observer.tagStatus('surface').value,
          tester.takeException().toString().contains('one or both endpoints did not have usable layout'),
        ),
        (MorphTagStatus.unmatched, true),
      );
    });

    testWidgets('when a local appearance changes, it should preserve the navigation result', (tester) async {
      final scenario = _MorphNavigationScenario(duration: const Duration(milliseconds: 300));
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pumpAndSettle();
      scenario.appearances[scenario.b]!.value = [scenario.c];
      await tester.pumpAndSettle();
      expect(scenario.observer.tagStatus('surface').value, MorphTagStatus.completed);
    });

    testWidgets('when a Navigator has no observer, it should explain the required setup', (tester) async {
      final target = MorphTarget(tag: 'surface');
      await tester.pumpWidget(
        MaterialApp(
          home: Morph(target: target, child: const SizedBox.square(dimension: 100)),
        ),
      );
      expect(tester.takeException().toString(), contains('MorphNavigatorObserver'));
    });

    testWidgets('when an observed route is pushed, it should transition between its actual endpoints', (tester) async {
      final scenario = _MorphNavigationScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pumpAndSettle();
      expect(scenario.received, ['B']);
    });

    testWidgets('when an observed route is popped, it should return to the route directly below it', (tester) async {
      final scenario = _MorphNavigationScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pumpAndSettle();
      scenario.received.clear();
      scenario.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(scenario.received, ['A']);
    });

    testWidgets('when the previous route has no match, it should not search through it on push', (tester) async {
      final scenario = _MorphNavigationScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(null);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pumpAndSettle();
      expect(scenario.started, isEmpty);
    });

    testWidgets('when the returning route has no match, it should not search through it on pop', (tester) async {
      final scenario = _MorphNavigationScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(null);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pumpAndSettle();
      scenario.started.clear();
      scenario.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(scenario.started, isEmpty);
    });

    testWidgets('when a gesture stops without movement, it should not start a flight', (tester) async {
      final scenario = _MorphNavigationScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pumpAndSettle();
      scenario.started.clear();
      scenario.navigator.currentState!
        ..didStartUserGesture()
        ..didStopUserGesture();
      await tester.pumpAndSettle();
      expect(scenario.started, isEmpty);
    });

    testWidgets('when two observers are registered on one Navigator, it should diagnose the duplicate setup', (
      tester,
    ) async {
      final target = MorphTarget(tag: 'surface');
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [MorphNavigatorObserver(), MorphNavigatorObserver()],
          home: Morph(target: target, child: const SizedBox.square(dimension: 100)),
        ),
      );
      expect(tester.takeException().toString(), contains('exactly one stable MorphNavigatorObserver'));
    });

    testWidgets('when the observer is added after Navigator creation, it should explain the lifetime requirement', (
      tester,
    ) async {
      final observer = MorphNavigatorObserver();
      final target = MorphTarget(tag: 'surface');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Morph(target: target, child: const SizedBox.square(dimension: 100)),
        ),
      );
      expect(tester.takeException().toString(), contains('from its creation'));
    });

    testWidgets(
      'when an observer from an old Navigator is attached late, it should validate the new Navigator lifetime',
      (tester) async {
        final observer = MorphNavigatorObserver();
        final target = MorphTarget(tag: 'surface');
        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('first-navigator'),
            navigatorObservers: [observer],
            home: const SizedBox(),
          ),
        );
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [observer],
            home: Morph(target: target, child: const SizedBox.square(dimension: 100)),
          ),
        );

        expect(tester.takeException().toString(), contains('from its creation'));
      },
    );

    testWidgets('when only the outer Navigator is observed, it should diagnose an unobserved nested Navigator', (
      tester,
    ) async {
      final target = MorphTarget(tag: 'surface');
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [MorphNavigatorObserver()],
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Morph(target: target, child: const SizedBox.square(dimension: 100)),
            ),
          ),
        ),
      );
      expect(tester.takeException().toString(), contains('Each nested Navigator needs its own observer'));
    });

    testWidgets('when a nested Navigator has its own observer, it should transition only its own appearances', (
      tester,
    ) async {
      final scenario = _MorphNavigationScenario();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [MorphNavigatorObserver()],
          home: Navigator(
            key: scenario.navigator,
            observers: [scenario.observer],
            onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => scenario.page(scenario.a)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pumpAndSettle();
      expect(scenario.started, ['A']);
    });

    testWidgets('when an appearance mounts in a background route, it should preserve the foreground owner', (
      tester,
    ) async {
      final scenario = _MorphNavigationScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pumpAndSettle();
      scenario.started.clear();
      scenario.appearances[scenario.a]!.value = [scenario.a, scenario.c];
      await tester.pumpAndSettle();
      expect(scenario.started, isEmpty);
    });

    testWidgets("when a route returns after a background arrival, it should use that route's latest appearance", (
      tester,
    ) async {
      final scenario = _MorphNavigationScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push(scenario.b);
      await tester.pumpAndSettle();
      scenario.appearances[scenario.a]!.value = [scenario.a, scenario.c];
      await tester.pumpAndSettle();
      scenario.received.clear();
      scenario.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(scenario.received, ['C']);
    });

    testWidgets('when the current route is replaced, it should treat the incoming route as a push', (tester) async {
      final scenario = _MorphNavigationScenario(duration: const Duration(milliseconds: 200));
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      final previous = ModalRoute.of(tester.element(find.byKey(const ValueKey('body-A'))))!;
      scenario.navigator.currentState!.replace<void>(
        oldRoute: previous,
        newRoute: MaterialPageRoute<void>(builder: (_) => scenario.page(scenario.b)),
      );
      await tester.pumpAndSettle();
      expect(
        [scenario.received, scenario.flights.single.kind],
        [
          ['B'],
          MorphFlightKind.routePush,
        ],
      );
    });

    testWidgets(
      'when a route is removed with an explicit duration, it should complete its independently timed return',
      (tester) async {
        final scenario = _MorphNavigationScenario(duration: const Duration(milliseconds: 200));
        await tester.pumpWidget(scenario.app);
        await tester.pumpAndSettle();
        scenario.push(scenario.b);
        await tester.pumpAndSettle();
        scenario.received.clear();
        final previous = ModalRoute.of(tester.element(find.byKey(const ValueKey('body-B'))))!;
        scenario.navigator.currentState!.removeRoute(previous);
        await tester.pumpAndSettle();
        expect(scenario.received, ['A']);
      },
    );

    testWidgets('when a declarative page list replaces its top page, it should transition to the new route as a push', (
      tester,
    ) async {
      final scenario = _MorphNavigationScenario(duration: const Duration(milliseconds: 200));
      final pages = ValueNotifier([scenario.a, scenario.b]);
      addTearDown(pages.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder(
            valueListenable: pages,
            builder: (context, targets, _) => Navigator(
              observers: [scenario.observer],
              onDidRemovePage: (_) {},
              pages: [
                for (final target in targets) MaterialPage<void>(key: ObjectKey(target), child: scenario.page(target)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      scenario.flights.clear();
      pages.value = [scenario.a, scenario.c];
      await tester.pumpAndSettle();
      expect(scenario.flights.single.kind, MorphFlightKind.routePush);
    });

    for (final action in ['pop', 'pushReplacement', 'go', 'replace']) {
      testWidgets('when GoRouter performs $action, it should select the matching appearance', (tester) async {
        final scenario = _MorphNavigationScenario(duration: const Duration(milliseconds: 200));
        final router = GoRouter(
          observers: [scenario.observer],
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (_, state) => MaterialPage<void>(key: state.pageKey, child: scenario.page(scenario.a)),
              routes: [
                GoRoute(
                  path: 'details',
                  pageBuilder: (_, state) => MaterialPage<void>(key: state.pageKey, child: scenario.page(scenario.b)),
                ),
                GoRoute(
                  path: 'alternate',
                  pageBuilder: (_, state) => MaterialPage<void>(key: state.pageKey, child: scenario.page(scenario.c)),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        unawaited(router.push<void>('/details'));
        await tester.pumpAndSettle();
        scenario.received.clear();
        switch (action) {
          case 'pop':
            router.pop();
          case 'pushReplacement':
            unawaited(router.pushReplacement<void>('/alternate'));
          case 'go':
            router.go('/alternate');
          case 'replace':
            unawaited(router.replace<void>('/alternate'));
        }
        await tester.pumpAndSettle();
        expect(scenario.received, [if (action == 'pop') 'A' else 'C']);
      });
    }

    testWidgets('when GoRouter forwards nested observer events, it should leave the outer appearance current', (
      tester,
    ) async {
      final scenario = _MorphNavigationScenario();
      final outer = MorphTarget(tag: 'surface');
      Animation<double>? outerProgress;
      final router = GoRouter(
        observers: [MorphNavigatorObserver()],
        routes: [
          ShellRoute(
            observers: [scenario.observer],
            builder: (_, _, child) => Stack(
              children: [
                Morph(target: outer, child: const SizedBox.square(dimension: 50)),
                MorphSibling(
                  target: outer,
                  transitionBuilder: (child, curved, _) {
                    outerProgress = curved;
                    return child;
                  },
                  child: const SizedBox.square(dimension: 50),
                ),
                child,
              ],
            ),
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (_, state) => MaterialPage<void>(key: state.pageKey, child: scenario.page(scenario.a)),
              ),
              GoRoute(
                path: '/details',
                pageBuilder: (_, state) => MaterialPage<void>(key: state.pageKey, child: scenario.page(scenario.b)),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      unawaited(router.push<void>('/details'));
      await tester.pumpAndSettle();
      expect(
        [scenario.started, outerProgress!.value],
        [
          ['A'],
          1.0,
        ],
      );
    });

    for (final duration in [null, const Duration(milliseconds: 400)]) {
      for (final commit in [false, true]) {
        testWidgets(
          'when a native back gesture ${commit ? 'completes' : 'cancels'} with ${duration == null ? 'route' : 'Morph'} timing, it should settle the accepted appearance',
          (tester) async {
            final scenario = _MorphNavigationScenario(duration: duration);
            tester.view.physicalSize = const Size(400, 700);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(scenario.app);
            await tester.pumpAndSettle();
            scenario.navigator.currentState!.push<void>(CupertinoPageRoute(builder: (_) => scenario.page(scenario.b)));
            await tester.pumpAndSettle();
            scenario.started.clear();
            final gesture = await tester.startGesture(const Offset(1, 350));
            await gesture.moveBy(const Offset(20, 0));
            await tester.pump();
            await gesture.moveBy(Offset(commit ? 300 : 80, 0));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 60));
            await gesture.up();
            await tester.pumpAndSettle();
            final current = ModalRoute.of(tester.element(find.byKey(ValueKey('body-${commit ? 'A' : 'B'}'))))!;
            expect(
              [
                scenario.observer.tagStatus('surface').value,
                current.isCurrent,
                scenario.started,
                scenario.progress[commit ? scenario.a : scenario.b]!.value,
                tester.takeException(),
              ],
              [
                if (commit) MorphTagStatus.completed else MorphTagStatus.cancelled,
                true,
                ['B'],
                1.0,
                null,
              ],
            );
          },
        );
      }
    }
  });
}
