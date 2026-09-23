import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../fixtures/morph_paint_probe/morph_paint_probe.dart';
import '../fixtures/morph_targets_test_delegate.dart';

void main() {
  final flight = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MorphFlightBoundary');

  Widget visual(List<MorphTarget> targets, {VoidCallback? onCapture, VoidCallback? onStart}) => Center(
    child: Morph(
      targets: targets,
      onStart: onStart,
      flightConfig: MorphFlightConfig.custom(MorphTargetsTestDelegate(onCapture: onCapture)),
      child: const SizedBox(width: 100, height: 100),
    ),
  );

  PageRoute<void> route(Widget child) => PageRouteBuilder<void>(
    transitionDuration: const Duration(seconds: 1),
    reverseTransitionDuration: const Duration(seconds: 1),
    pageBuilder: (_, _, _) => Scaffold(body: child),
  );

  Future<NavigatorState> mount(WidgetTester tester, Widget child, {MorphNavigatorObserver? observer}) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [observer ?? MorphNavigatorObserver()],
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  Future<void> advance(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final navigation in [false, true]) {
    for (final policy in ['accept', 'reject-source', 'reject-destination', 'fallback', 'missing']) {
      testWidgets('when $policy matches with navigation=$navigation, it should resolve first-paint visibility', (
        tester,
      ) async {
        var paints = 0;
        final decisions = <String>[];
        final target = MorphTarget(
          tag: 'first-paint',
          canMatch: (_) {
            decisions.add('contract');
            return policy != 'reject-source' && policy != 'reject-destination';
          },
        );
        final source = visual([target]);
        final incoming = ValueNotifier<Widget>(const SizedBox.shrink());
        addTearDown(incoming.dispose);
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          WidgetsApp(
            color: const Color(0xFFFFFFFF),
            navigatorKey: navigatorKey,
            navigatorObservers: [MorphNavigatorObserver()],
            pageRouteBuilder: <T>(settings, builder) =>
                PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, _) => builder(context)),
            home: Stack(
              children: [
                source,
                ValueListenableBuilder<Widget>(valueListenable: incoming, builder: (_, child, _) => child),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final destination = Center(
          child: Morph(
            targets: [
              if (policy == 'fallback') MorphTarget(tag: 'missing'),
              if (policy == 'missing') MorphTarget(tag: 'unmatched') else target,
            ],
            flightConfig: const MorphFlightConfig.custom(MorphTargetsTestDelegate()),
            child: MorphPaintProbe(onPaint: () => paints++, child: const SizedBox(width: 100, height: 100)),
          ),
        );
        if (navigation) {
          navigatorKey.currentState!.push<void>(
            PageRouteBuilder<void>(
              transitionDuration: const Duration(seconds: 1),
              transitionsBuilder: (_, _, _, child) => child,
              pageBuilder: (_, _, _) => destination,
            ),
          );
        } else {
          incoming.value = destination;
        }
        await tester.pump();
        expect(
          (paints, decisions.join(',')),
          (
            policy == 'accept' || policy == 'fallback' ? 0 : 1,
            policy == 'missing' ? '' : 'contract',
          ),
        );
        await tester.pumpAndSettle();
      });
    }
  }

  testWidgets('when an eligible endpoint cannot be captured, it should release its painting hold', (tester) async {
    var paints = 0;
    var starts = 0;
    final incoming = ValueNotifier<Widget>(const SizedBox.shrink());
    addTearDown(incoming.dispose);
    final targetUnavailable = MorphTarget(tag: 'unavailable', canMatch: (_) => true);
    await mount(
      tester,
      Stack(
        children: [
          visual([targetUnavailable]),
          ValueListenableBuilder<Widget>(valueListenable: incoming, builder: (_, child, _) => child),
        ],
      ),
    );
    incoming.value = Center(
      child: Morph(
        targets: [targetUnavailable],
        onStart: () => starts++,
        flightConfig: const MorphFlightConfig.custom(MorphTargetsTestDelegate()),
        child: MorphPaintProbe(onPaint: () => paints++, child: const SizedBox.shrink()),
      ),
    );
    await tester.pump();
    final error = tester.takeException();
    await tester.pumpAndSettle();
    expect((paints > 0, starts, error.toString().contains('usable layout')), (true, 0, true));
  });

  testWidgets('when the shared contract rejects, it should avoid capture and callbacks', (tester) async {
    final events = <String>[];
    final targetA = MorphTarget(
      tag: 'a',
      canMatch: (_) {
        events.add('contract');
        return false;
      },
    );
    final navigator = await mount(
      tester,
      visual(
        [
          targetA,
        ],
        onCapture: () => events.add('capture'),
        onStart: () => events.add('start'),
      ),
    );
    events.clear();
    navigator.push<void>(
      route(
        visual([
          targetA,
        ], onCapture: () => events.add('capture')),
      ),
    );
    await advance(tester);
    expect(events, ['contract']);
    await tester.pumpAndSettle();
  });

  testWidgets('when the shared contract approves, it should receive the route context once', (tester) async {
    final contexts = <(String, MorphMatchContext)>[];
    final targetA = MorphTarget(
      tag: 'a',
      canMatch: (match) {
        contexts.add(('source', match));
        return true;
      },
    );
    final navigator = await mount(
      tester,
      visual([
        targetA,
      ]),
    );
    final sourceRoute = ModalRoute.of(tester.element(find.byType(Morph)));
    final destinationRoute = route(
      visual([
        targetA,
      ]),
    );
    navigator.push<void>(destinationRoute);
    await advance(tester);
    expect(
      (
        contexts.map((entry) => entry.$1).join(','),
        identical(contexts.first.$2, contexts.last.$2),
        contexts.first.$2.sourceRoute,
        contexts.first.$2.destinationRoute,
        contexts.first.$2.operation,
      ),
      ('source', true, sourceRoute, destinationRoute, MorphMatchOperation.push),
    );
    await tester.pumpAndSettle();
  });

  for (final throws in [false, true]) {
    testWidgets('when the first target ${throws ? 'throws' : 'rejects'}, it should use the next target', (
      tester,
    ) async {
      final targetB = MorphTarget(tag: 'b');

      final observer = MorphNavigatorObserver();
      final targetA = MorphTarget(
        tag: 'a',
        canMatch: (_) {
          if (throws) throw StateError('predicate failed');
          return false;
        },
      );
      final navigator = await mount(
        tester,
        visual([targetA, targetB]),
        observer: observer,
      );
      navigator.push<void>(
        route(
          visual([
            targetA,
            targetB,
          ]),
        ),
      );
      await advance(tester);
      final error = tester.takeException();
      expect(
        (targetA.status.value, targetB.status.value, error is StateError),
        (MorphTagStatus.unmatched, MorphTagStatus.flying, throws),
      );
      await tester.pumpAndSettle();
    });
  }

  testWidgets('when popping after push, it should check current policy with reversed routes', (tester) async {
    var allow = true;
    final contexts = <MorphMatchContext>[];
    final targetA = MorphTarget(
      tag: 'a',
      canMatch: (match) {
        contexts.add(match);
        return allow;
      },
    );
    final navigator = await mount(
      tester,
      visual([
        targetA,
      ]),
    );
    navigator.push<void>(route(visual([targetA])));
    await tester.pumpAndSettle();
    allow = false;
    navigator.pop();
    await advance(tester);
    expect(
      (
        contexts.map((match) => match.operation.name).join(','),
        contexts.last.sourceRoute == contexts.first.destinationRoute,
        contexts.last.destinationRoute == contexts.first.sourceRoute,
        flight.evaluate().length,
      ),
      ('push,pop', true, true, 0),
    );
    await tester.pumpAndSettle();
  });

  for (final operation in ['pushReplacement', 'replace', 'remove', 'pushAndRemoveUntil']) {
    testWidgets('when using $operation, it should report the observed top-route operation', (tester) async {
      final contexts = <MorphMatchContext>[];
      final target = MorphTarget(
        tag: 'a',
        canMatch: (match) {
          contexts.add(match);
          return true;
        },
      );
      final navigator = await mount(tester, visual([target]));
      final first = ModalRoute.of(tester.element(find.byType(Morph)))!;
      final second = route(visual([target]));
      switch (operation) {
        case 'pushReplacement':
          navigator.pushReplacement<void, void>(second);
        case 'replace':
          navigator.replace(oldRoute: first, newRoute: second);
        case 'remove':
          navigator.push<void>(second);
          await tester.pumpAndSettle();
          contexts.clear();
          navigator.removeRoute(second);
        case 'pushAndRemoveUntil':
          navigator.pushAndRemoveUntil<void>(second, (_) => false);
      }
      await advance(tester);
      expect(contexts.map((context) => context.operation).toSet(), {
        switch (operation) {
          'remove' => MorphMatchOperation.remove,
          'pushAndRemoveUntil' => MorphMatchOperation.push,
          _ => MorphMatchOperation.replace,
        },
      });
      await tester.pumpAndSettle();
    });
  }

  for (final standalone in [false, true]) {
    testWidgets('when matching locally standalone=$standalone, it should report enclosing routes', (tester) async {
      final contexts = <MorphMatchContext>[];
      final targetA = MorphTarget(
        tag: 'a',
        canMatch: (match) {
          contexts.add(match);
          return false;
        },
      );
      final source = targetA;
      final destination = targetA;
      var show = false;
      late StateSetter update;
      final scene = StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return Stack(
            children: [
              visual([source]),
              if (show) visual([destination]),
            ],
          );
        },
      );
      if (standalone) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Overlay(initialEntries: [OverlayEntry(builder: (_) => scene)]),
          ),
        );
        await tester.pumpAndSettle();
      } else {
        await mount(tester, scene);
      }
      update(() => show = true);
      await advance(tester);
      expect(
        (
          contexts.single.operation,
          identical(contexts.single.sourceRoute, contexts.single.destinationRoute),
          contexts.single.sourceRoute == null,
          flight.evaluate().length,
        ),
        (MorphMatchOperation.local, true, standalone, 0),
      );
      await tester.pumpAndSettle();
    });
  }

  for (final commit in [false, true]) {
    testWidgets('when a Back gesture commit=$commit changes direction, it should retain its eligibility', (
      tester,
    ) async {
      final contexts = <MorphMatchContext>[];
      var allow = true;
      final targetA = MorphTarget(
        tag: 'a',
        canMatch: (match) {
          contexts.add(match);
          return allow;
        },
      );
      final navigator = await mount(
        tester,
        visual([
          targetA,
        ]),
      );
      navigator.push<void>(
        CupertinoPageRoute<void>(
          builder: (_) => CupertinoPageScaffold(child: visual([targetA])),
        ),
      );
      await tester.pumpAndSettle();
      contexts.clear();
      final gesture = await tester.startGesture(const Offset(1, 200));
      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();
      await tester.pump();
      allow = false;
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await gesture.moveBy(Offset(commit ? 500 : -200, 0));
      if (!commit) await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        (contexts.map((context) => context.operation.name).join(','), navigator.canPop()),
        ('pop', !commit),
      );
    });
  }

  testWidgets('when replacing a child in place, it should not consult canMatch', (tester) async {
    var checks = 0;
    var version = 0;
    late StateSetter update;
    final target = MorphTarget(
      tag: 'a',
      canMatch: (_) {
        checks++;
        return false;
      },
    );
    await mount(
      tester,
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return Center(
            child: Morph(
              targets: [target],

              child: Container(key: ValueKey(version), width: 100, height: 100, color: Colors.red),
            ),
          );
        },
      ),
    );
    update(() => version++);
    await advance(tester);
    expect((checks, flight.evaluate().length), (0, 0));
    await tester.pumpAndSettle();
  });

  testWidgets('when a pop is vetoed, it should not propose a return match', (tester) async {
    final contexts = <MorphMatchContext>[];
    final targetA = MorphTarget(
      tag: 'a',
      canMatch: (match) {
        contexts.add(match);
        return true;
      },
    );
    final navigator = await mount(tester, visual([targetA]));
    navigator.push<void>(
      route(
        PopScope(
          canPop: false,
          child: visual([
            targetA,
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    contexts.clear();
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect((contexts.length, navigator.canPop()), (0, true));
  });

  testWidgets('when the observer cannot identify a top change, it should report unknown', (tester) async {
    final contexts = <MorphMatchContext>[];
    final observer = MorphNavigatorObserver();
    final targetA = MorphTarget(
      tag: 'a',
      canMatch: (match) {
        contexts.add(match);
        return false;
      },
    );
    final navigator = await mount(
      tester,
      visual([
        targetA,
      ]),
      observer: observer,
    );
    final first = ModalRoute.of(tester.element(find.byType(Morph)))!;
    final second = route(visual([targetA]));
    navigator.push<void>(second);
    await tester.pumpAndSettle();
    contexts.clear();
    observer.didChangeTop(first, second);
    await advance(tester);
    expect(contexts.single.operation, MorphMatchOperation.unknown);
    await tester.pumpAndSettle();
  });

  testWidgets('when a background route is replaced, it should not misclassify the next pop', (tester) async {
    final operations = <MorphMatchOperation>[];
    final target = MorphTarget(
      tag: 'a',
      canMatch: (match) {
        operations.add(match.operation);
        return true;
      },
    );
    final navigator = await mount(tester, visual([target]));
    final first = ModalRoute.of(tester.element(find.byType(Morph)))!;
    navigator.push<void>(route(visual([target])));
    await tester.pumpAndSettle();
    navigator.replace(oldRoute: first, newRoute: route(visual([target])));
    await tester.pumpAndSettle();
    operations.clear();
    navigator.pop();
    await advance(tester);
    expect(operations.toSet(), {MorphMatchOperation.pop});
    await tester.pumpAndSettle();
  });

  testWidgets('when policy changes during a flight, it should finish without a fallback entrance', (tester) async {
    var allow = true;
    var checks = 0;
    var fallbackChecks = 0;
    final observer = MorphNavigatorObserver();
    final targetA = MorphTarget(
      tag: 'a',
      canMatch: (_) {
        checks++;
        return allow;
      },
    );
    final targetB = MorphTarget(
      tag: 'b',
      canMatch: (_) {
        fallbackChecks++;
        return true;
      },
    );
    final navigator = await mount(
      tester,
      visual([targetA, targetB]),
      observer: observer,
    );
    late StateSetter update;
    final targets = [
      targetA,
      targetB,
    ];
    navigator.push<void>(
      route(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return visual(targets);
          },
        ),
      ),
    );
    await advance(tester);
    update(() => allow = false);
    await tester.pumpAndSettle();
    expect(
      (checks, fallbackChecks, targetA.status.value, targetB.status.value),
      (1, 0, MorphTagStatus.completed, MorphTagStatus.unmatched),
    );
  });

  testWidgets('when a rapid pop rejects, it should interrupt the push without replaying an entrance', (tester) async {
    var starts = 0;
    final targetA = MorphTarget(tag: 'a', canMatch: (match) => match.operation == MorphMatchOperation.push);
    final navigator = await mount(
      tester,
      visual([
        targetA,
      ], onStart: () => starts++),
    );
    navigator.push<void>(route(visual([targetA], onStart: () => starts++)));
    await advance(tester);
    navigator.pop();
    await tester.pumpAndSettle();
    expect((starts, flight.evaluate().length, navigator.canPop()), (1, 0, false));
  });
}
