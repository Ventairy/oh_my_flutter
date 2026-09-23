import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../fixtures/morph_targets_test_delegate.dart';

void main() {
  final flight = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MorphFlightBoundary');

  Future<NavigatorState> mount(WidgetTester tester, MorphNavigatorObserver observer, Widget source) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [observer],
        home: Scaffold(body: source),
      ),
    );
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  Future<void> push(WidgetTester tester, NavigatorState navigator, Widget destination) async {
    navigator.push<void>(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(seconds: 1),
        reverseTransitionDuration: const Duration(seconds: 1),
        pageBuilder: (_, _, _) => Scaffold(body: destination),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Widget visual(List<MorphTarget> targets, {VoidCallback? onStart, VoidCallback? onEnd, VoidCallback? onReceived}) =>
      Center(
        child: Morph(
          targets: targets,
          onStart: onStart,
          onEnd: onEnd,
          onReceived: onReceived,
          child: Container(width: 100, height: 100, color: Colors.red),
        ),
      );

  testWidgets('when separate target instances have equal tags, it should leave them unmatched', (tester) async {
    final observer = MorphNavigatorObserver();
    final target = MorphTarget(tag: 'equal');
    final navigator = await mount(tester, observer, visual([target]));
    await push(tester, navigator, visual([MorphTarget(tag: 'equal')]));
    expect(target.status.value, MorphTagStatus.unmatched);
    await tester.pumpAndSettle();
  });

  for (final fast in [false, true]) {
    testWidgets('when the selected contract is fast=$fast, it should use its duration and curve in both directions', (
      tester,
    ) async {
      final slow = MorphTarget(tag: 'slow', duration: const Duration(milliseconds: 800), curve: Curves.easeIn);
      final quick = MorphTarget(tag: 'quick', duration: const Duration(milliseconds: 200), curve: Curves.linear);
      final selected = fast ? quick : slow;
      MorphFlight<int>? active;
      final config = MorphFlightConfig.custom(MorphTargetsTestDelegate(onFlight: (flight) => active = flight));
      Widget endpoint(List<MorphTarget> targets) => Center(
        child: Morph(
          targets: targets,
          flightConfig: config,
          child: const SizedBox(width: 100, height: 100),
        ),
      );
      final observer = MorphNavigatorObserver();
      final navigator = await mount(tester, observer, endpoint([slow, quick]));
      await push(tester, navigator, endpoint([selected]));
      final forward = active!.curvedAnimation.value;
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        (forward, active!.curvedAnimation.value),
        (selected.curve!.transform(fast ? .5 : .125), selected.curve!.transform(fast ? .5 : .125)),
      );
      await tester.pumpAndSettle();
    });
  }

  for (final first in ['a', 'b']) {
    testWidgets('destination prefers $first regardless of source order and flies once', (tester) async {
      final observer = MorphNavigatorObserver();
      final events = <String>[];
      final connections = {
        for (final tag in ['a', 'b']) tag: MorphTarget(tag: tag),
      };
      final navigator = await mount(
        tester,
        observer,
        visual(
          [connections['a']!, connections['b']!],
          onStart: () => events.add('start'),
          onEnd: () => events.add('end'),
        ),
      );
      await push(
        tester,
        navigator,
        visual(
          [connections[first]!, connections[first == 'a' ? 'b' : 'a']!],
          onReceived: () => events.add('received'),
        ),
      );
      expect(connections[first]!.status.value, MorphTagStatus.flying);
      expect(connections[first == 'a' ? 'b' : 'a']!.status.value, MorphTagStatus.unmatched);
      expect(flight, findsOneWidget);
      expect(events, ['start']);
      await tester.pumpAndSettle();
      expect(events, ['start', 'received', 'end']);
      navigator.pop();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(connections['a']!.status.value, MorphTagStatus.flying);
      expect(flight, findsOneWidget);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('missing first target falls back to second', (tester) async {
    final targetFallback = MorphTarget(tag: 'fallback');

    final observer = MorphNavigatorObserver();
    final navigator = await mount(tester, observer, visual([targetFallback]));
    final missing = MorphTarget(tag: 'missing');
    await push(tester, navigator, visual([missing, targetFallback]));
    expect(missing.status.value, MorphTagStatus.unmatched);
    expect(targetFallback.status.value, MorphTagStatus.flying);
    expect(flight, findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('no matching alternatives renders normally', (tester) async {
    final observer = MorphNavigatorObserver();
    final navigator = await mount(tester, observer, visual([MorphTarget(tag: 'source')]));
    final targetA = MorphTarget(tag: 'a');
    final targetB = MorphTarget(tag: 'b');
    await push(tester, navigator, visual([targetA, targetB]));
    expect(flight, findsNothing);
    expect(targetA.status.value, MorphTagStatus.unmatched);
    expect(targetB.status.value, MorphTagStatus.unmatched);
    await tester.pumpAndSettle();
    expect(find.byType(Morph).hitTestable(), findsOneWidget);
  });

  testWidgets('one source cannot be claimed by two arriving visuals', (tester) async {
    final targetA = MorphTarget(tag: 'a');

    final targetB = MorphTarget(tag: 'b');

    final observer = MorphNavigatorObserver();
    final navigator = await mount(tester, observer, visual([targetA, targetB]));
    await push(
      tester,
      navigator,
      Row(
        children: [
          Expanded(child: visual([targetA])),
          Expanded(child: visual([targetB])),
        ],
      ),
    );
    expect(flight, findsOneWidget);
    expect(targetA.status.value, MorphTagStatus.flying);
    expect(targetB.status.value, MorphTagStatus.unmatched);
    await tester.pumpAndSettle();
    expect(find.byType(Morph).hitTestable(), findsNWidgets(2));
  });

  testWidgets('local appearances use ordered fallback and return', (tester) async {
    final targetShared = MorphTarget(tag: 'shared');

    final source = [MorphTarget(tag: 'unused'), targetShared];
    final destination = [MorphTarget(tag: 'missing'), targetShared];
    var show = false;
    late StateSetter update;
    await mount(
      tester,
      MorphNavigatorObserver(),
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return Stack(
            children: [
              Align(alignment: Alignment.topLeft, child: visual(source)),
              if (show) Align(alignment: Alignment.bottomRight, child: visual(destination)),
            ],
          );
        },
      ),
    );
    update(() => show = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(flight, findsOneWidget);
    await tester.pumpAndSettle();
    update(() => show = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(flight, findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('incompatible first source falls back to a compatible source', (tester) async {
    final targetIncompatible = MorphTarget(tag: 'incompatible');

    final targetFallback = MorphTarget(tag: 'fallback');

    final observer = MorphNavigatorObserver();
    final navigator = await mount(
      tester,
      observer,
      Row(
        children: [
          Expanded(
            child: Morph(
              targets: [targetIncompatible],
              flightConfig: const MorphFlightConfig.custom(MorphTargetsTestDelegate()),
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
          Expanded(child: visual([targetFallback])),
        ],
      ),
    );
    await push(tester, navigator, visual([targetIncompatible, targetFallback]));
    expect(targetIncompatible.status.value, MorphTagStatus.unmatched);
    expect(targetFallback.status.value, MorphTagStatus.flying);
    expect(flight, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('unusable first source falls back without a capture diagnostic', (tester) async {
    final targetEmpty = MorphTarget(tag: 'empty');

    final targetFallback = MorphTarget(tag: 'fallback');

    final observer = MorphNavigatorObserver();
    final navigator = await mount(
      tester,
      observer,
      Stack(
        children: [
          SizedBox.shrink(
            child: Morph(
              targets: [targetEmpty],
              child: const SizedBox.shrink(),
            ),
          ),
          visual([targetFallback]),
        ],
      ),
    );
    await push(tester, navigator, visual([targetEmpty, targetFallback]));
    expect(targetEmpty.status.value, MorphTagStatus.unmatched);
    expect(targetFallback.status.value, MorphTagStatus.flying);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });

  for (final duringFlight in [false, true]) {
    testWidgets('reorder duringFlight=$duringFlight does not replay the entrance', (tester) async {
      final targetA = MorphTarget(tag: 'a');

      final targetB = MorphTarget(tag: 'b');

      final observer = MorphNavigatorObserver();
      var starts = 0;
      final navigator = await mount(
        tester,
        observer,
        visual(
          [targetA, targetB],
          onStart: () => starts++,
        ),
      );
      final a = targetA;
      final b = targetB;
      var targets = [a, b];
      late StateSetter update;
      await push(
        tester,
        navigator,
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return visual(targets);
          },
        ),
      );
      if (!duringFlight) await tester.pumpAndSettle();
      update(() => targets = [b, a]);
      await tester.pump();
      if (duringFlight) expect(targetA.status.value, MorphTagStatus.flying);
      expect(targetB.status.value, MorphTagStatus.unmatched);
      expect(starts, 1);
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(find.byType(Morph).hitTestable(), findsOneWidget);
    });
  }

  testWidgets('removing the selected target cancels without trying an alternative', (tester) async {
    final targetA = MorphTarget(tag: 'a');

    final targetB = MorphTarget(tag: 'b');

    final observer = MorphNavigatorObserver();
    var starts = 0;
    final navigator = await mount(
      tester,
      observer,
      visual(
        [targetA, targetB],
        onStart: () => starts++,
      ),
    );
    final a = targetA;
    final b = targetB;
    var targets = [a, b];
    late StateSetter update;
    await push(
      tester,
      navigator,
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return visual(targets);
        },
      ),
    );
    update(() => targets = [b]);
    await tester.pumpAndSettle();
    expect(flight, findsNothing);
    expect(starts, 1);
    expect(targetB.status.value, MorphTagStatus.unmatched);
    expect(find.byType(Morph).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('when a child changes, it should not start a flight', (tester) async {
    final targets = [MorphTarget(tag: 'a'), MorphTarget(tag: 'b')];
    var version = 0;
    var starts = 0;
    late StateSetter update;
    await mount(
      tester,
      MorphNavigatorObserver(),
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return Center(
            child: Morph(
              targets: targets,

              onStart: () => starts++,
              child: Container(key: ValueKey(version), width: 100, height: 100, color: Colors.red),
            ),
          );
        },
      ),
    );
    update(() => version++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(flight, findsNothing);
    expect(starts, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('all incompatible alternatives display normally without starting callbacks', (tester) async {
    final targetA = MorphTarget(tag: 'a');

    final targetB = MorphTarget(tag: 'b');

    final observer = MorphNavigatorObserver();
    var starts = 0;
    final navigator = await mount(
      tester,
      observer,
      Center(
        child: Morph(
          targets: [
            targetA,
            targetB,
          ],
          onStart: () => starts++,
          flightConfig: const MorphFlightConfig.custom(MorphTargetsTestDelegate()),
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );
    await push(tester, navigator, visual([targetA, targetB]));
    expect(flight, findsNothing);
    expect(starts, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(Morph).hitTestable(), findsOneWidget);
  });

  testWidgets('the internal snapshot detects edits to a reused list', (tester) async {
    final targetA = MorphTarget(tag: 'a');

    final targetB = MorphTarget(tag: 'b');

    final observer = MorphNavigatorObserver();
    final navigator = await mount(tester, observer, visual([targetA, targetB]));
    final a = targetA;
    final b = targetB;
    final targets = [a, b];
    late StateSetter update;
    await push(
      tester,
      navigator,
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return visual(targets);
        },
      ),
    );
    update(() => targets.remove(a));
    await tester.pumpAndSettle();
    expect(targetB.status.value, MorphTagStatus.unmatched);
    expect(flight, findsNothing);
    expect(find.byType(Morph).hitTestable(), findsOneWidget);
  });

  for (final commit in [false, true]) {
    testWidgets('Cupertino swipe commit=$commit retains one accepted relationship', (tester) async {
      final targetA = MorphTarget(tag: 'a');

      final targetB = MorphTarget(tag: 'b');

      final observer = MorphNavigatorObserver();
      final navigator = await mount(tester, observer, visual([targetA, targetB]));
      navigator.push<void>(
        CupertinoPageRoute<void>(
          builder: (_) => CupertinoPageScaffold(
            child: visual([targetB, targetA]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(1, 200));
      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();
      await tester.pump();
      expect(flight, findsOneWidget);
      expect(targetA.status.value, MorphTagStatus.flying);
      expect(targetB.status.value, MorphTagStatus.unmatched);
      if (commit) {
        await gesture.moveBy(const Offset(500, 0));
      } else {
        await gesture.moveBy(const Offset(-180, 0));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(flight, findsNothing);
      expect(navigator.canPop(), !commit);
      expect(find.byType(Morph).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rapid push and pop restores one live visual', (tester) async {
    final targetA = MorphTarget(tag: 'a');

    final targetB = MorphTarget(tag: 'b');

    final observer = MorphNavigatorObserver();
    final navigator = await mount(tester, observer, visual([targetA, targetB]));
    await push(tester, navigator, visual([targetB, targetA]));
    navigator.pop();
    await tester.pumpAndSettle();
    expect(flight, findsNothing);
    expect(find.byType(Morph).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing a destination in flight restores the source', (tester) async {
    final targetA = MorphTarget(tag: 'a');

    final targetB = MorphTarget(tag: 'b');

    final observer = MorphNavigatorObserver();
    final navigator = await mount(tester, observer, visual([targetA, targetB]));
    final route = PageRouteBuilder<void>(
      transitionDuration: const Duration(seconds: 1),
      pageBuilder: (_, _, _) => visual([targetB, targetA]),
    );
    navigator.push<void>(route);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    navigator.removeRoute(route);
    await tester.pumpAndSettle();
    expect(flight, findsNothing);
    expect(find.byType(Morph).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matching two tags captures each visual once', (tester) async {
    final targetA = MorphTarget(tag: 'a');

    final targetB = MorphTarget(tag: 'b');

    var captures = 0;
    final delegate = MorphTargetsTestDelegate(onCapture: () => captures++);
    Widget captured(List<MorphTarget> targets) => Center(
      child: Morph(
        targets: targets,
        flightConfig: MorphFlightConfig.custom(delegate),
        child: const SizedBox(width: 100, height: 100),
      ),
    );
    final navigator = await mount(
      tester,
      MorphNavigatorObserver(),
      captured([targetA, targetB]),
    );
    captures = 0;
    await push(tester, navigator, captured([targetB, targetA]));
    expect(captures, 2);
    expect(flight, findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a covered visual cannot start a child replacement through an unused target', (tester) async {
    final targetShared = MorphTarget(tag: 'shared');

    final source = [MorphTarget(tag: 'unused'), targetShared];
    final destination = [targetShared, MorphTarget(tag: 'another')];
    var show = false;
    var version = 0;
    var starts = 0;
    late StateSetter update;
    await mount(
      tester,
      MorphNavigatorObserver(),
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return Stack(
            children: [
              Center(
                child: Morph(
                  targets: source,

                  onStart: () => starts++,
                  child: Container(key: ValueKey(version), width: 100, height: 100, color: Colors.red),
                ),
              ),
              if (show) visual(destination),
            ],
          );
        },
      ),
    );
    update(() => show = true);
    await tester.pumpAndSettle();
    final before = starts;
    update(() => version++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(flight, findsNothing);
    expect(starts, before);
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion does not start alternative flights', (tester) async {
    final targetA = MorphTarget(tag: 'a');

    final targetB = MorphTarget(tag: 'b');

    final observer = MorphNavigatorObserver();
    var starts = 0;
    final navigator = await mount(
      tester,
      observer,
      visual(
        [targetA, targetB],
        onStart: () => starts++,
      ),
    );
    await push(
      tester,
      navigator,
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: visual([targetB, targetA]),
      ),
    );
    expect(flight, findsNothing);
    expect(starts, 0);
    expect(targetA.status.value, MorphTagStatus.unmatched);
    expect(targetB.status.value, MorphTagStatus.unmatched);
    await tester.pumpAndSettle();
  });

  testWidgets('equal alternative tags in independent nested Navigators stay isolated', (tester) async {
    final targetA = MorphTarget(tag: 'a');

    final targetB = MorphTarget(tag: 'b');

    final firstObserver = MorphNavigatorObserver();
    final secondObserver = MorphNavigatorObserver();
    final firstKey = GlobalKey<NavigatorState>();
    final secondKey = GlobalKey<NavigatorState>();
    var secondStarts = 0;
    await mount(
      tester,
      MorphNavigatorObserver(),
      Row(
        children: [
          Expanded(
            child: Navigator(
              key: firstKey,
              observers: [firstObserver],
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => visual([targetA, targetB]),
              ),
            ),
          ),
          Expanded(
            child: Navigator(
              key: secondKey,
              observers: [secondObserver],
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => visual([targetA, targetB], onStart: () => secondStarts++),
              ),
            ),
          ),
        ],
      ),
    );
    await push(tester, firstKey.currentState!, visual([targetB, targetA]));
    expect(flight, findsOneWidget);
    expect(targetB.status.value, MorphTagStatus.flying);
    expect(secondStarts, 0);
    expect(secondKey.currentState!.canPop(), isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('when distinct alternatives have equal tags, it should accept their independent contracts', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: visual([MorphTarget(tag: 'equal'), MorphTarget(tag: 'equal')]),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  for (final invalid in ['empty', 'same instance']) {
    testWidgets('when targets are $invalid, it should reject the configuration', (tester) async {
      final target = MorphTarget(tag: 'a');
      final targets = switch (invalid) {
        'empty' => <MorphTarget>[],
        _ => [target, target],
      };
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: visual(targets)));
      expect(tester.takeException(), isAssertionError);
    });
  }
}
