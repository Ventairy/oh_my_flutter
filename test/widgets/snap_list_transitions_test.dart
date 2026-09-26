import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'snap_list_test.dart' show SnapListTestHost;

class _TransitionHost {
  final controller = SnapListController();
  final incomingAnimations = <int, (Animation<double>, bool)>{};
  final outgoingAnimations = <int, (Animation<double>, bool)>{};
  Map<int, (double, bool)> get incoming =>
      incomingAnimations.map((index, value) => MapEntry(index, (value.$1.value, value.$2)));
  Map<int, (double, bool)> get outgoing =>
      outgoingAnimations.map((index, value) => MapEntry(index, (value.$1.value, value.$2)));
  int builds = 0;
  int effects = 0;

  Widget _incoming(BuildContext context, Animation<double> progress, SnapListTransitionDetails details, Widget child) {
    incomingAnimations[(child.key! as ValueKey<int>).value] = (progress, details.isReverse);
    effects++;
    return FadeTransition(key: child.key, opacity: progress, child: child);
  }

  Widget _outgoing(BuildContext context, Animation<double> progress, SnapListTransitionDetails details, Widget child) {
    outgoingAnimations[(child.key! as ValueKey<int>).value] = (progress, details.isReverse);
    effects++;
    return ScaleTransition(key: child.key, scale: Tween<double>(begin: 1, end: .9).animate(progress), child: child);
  }

  Widget _item(int index) => Builder(
    key: ValueKey(index),
    builder: (_) {
      builds++;
      return Text('Item $index');
    },
  );

  Future<void> mount(
    WidgetTester tester, {
    bool lazy = false,
    bool withIncoming = true,
    bool withOutgoing = true,
    bool reducedMotion = false,
    bool settle = true,
    Axis axis = Axis.vertical,
    TextDirection direction = TextDirection.ltr,
    int count = 4,
    double spacing = 0,
    WidgetBuilder? trailingBuilder,
  }) async {
    await tester.pumpWidget(
      SnapListTestHost.app(
        Directionality(
          textDirection: direction,
          child: lazy
              ? SnapList.builder(
                  controller: controller,
                  axis: axis,
                  spacing: spacing,
                  duration: const Duration(milliseconds: 400),
                  incomingTransitionBuilder: withIncoming ? _incoming : null,
                  outgoingTransitionBuilder: withOutgoing ? _outgoing : null,
                  itemCount: count,
                  itemBuilder: (_, index) => _item(index),
                  trailingBuilder: trailingBuilder,
                )
              : SnapList(
                  controller: controller,
                  axis: axis,
                  spacing: spacing,
                  duration: const Duration(milliseconds: 400),
                  incomingTransitionBuilder: withIncoming ? _incoming : null,
                  outgoingTransitionBuilder: withOutgoing ? _outgoing : null,
                  trailingBuilder: trailingBuilder,
                  children: List.generate(count, _item),
                ),
        ),
        reducedMotion: reducedMotion,
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> position(WidgetTester tester, double value) async {
    final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final list = tester.widget<SnapList>(find.byType(SnapList));
    final size = tester.getSize(find.byType(SnapList));
    state.position.jumpTo(value * ((list.axis == Axis.vertical ? size.height : size.width) + list.spacing));
    await tester.pump();
  }
}

void main() {
  for (final lazy in [false, true]) {
    group(lazy ? 'lazy' : 'eager', () {
      for (final enabled in [(true, false), (false, true), (true, true), (false, false)]) {
        testWidgets('when builders are $enabled, it should apply only the configured effects', (tester) async {
          final host = _TransitionHost();
          await host.mount(tester, lazy: lazy, withIncoming: enabled.$1, withOutgoing: enabled.$2);
          await host.position(tester, .5);
          expect(
            (host.incoming[1], host.outgoing[0]),
            (enabled.$1 ? (.5, false) : null, enabled.$2 ? (.5, false) : null),
          );
        });
      }

      testWidgets('when progress changes within the prepared range, it should keep builders and item content cached', (
        tester,
      ) async {
        final host = _TransitionHost();
        await host.mount(tester, lazy: lazy);
        await host.position(tester, .25);
        final initial = (host.builds, host.effects);
        await host.position(tester, .5);
        await host.position(tester, .75);
        expect((host.builds - initial.$1, host.effects - initial.$2), (0, 0));
      });

      testWidgets('when mounted, it should use resting values', (tester) async {
        final host = _TransitionHost();
        await host.mount(tester, lazy: lazy);
        expect((host.incoming[0], host.outgoing[0]), ((1.0, false), (0.0, false)));
      });

      testWidgets('when a transition rewinds, it should retain its roles and direction', (tester) async {
        final host = _TransitionHost();
        await host.mount(tester, lazy: lazy);
        await host.position(tester, .6);
        await host.position(tester, .25);
        expect((host.incoming[1], host.outgoing[0]), ((.25, false), (.25, false)));
      });

      testWidgets('when returning to the origin, it should restore normal appearance', (tester) async {
        final host = _TransitionHost();
        await host.mount(tester, lazy: lazy);
        await host.position(tester, .5);
        await host.position(tester, 0);
        expect((host.incoming[0], host.outgoing[0]), ((1.0, false), (0.0, false)));
      });

      testWidgets('when moving backward, it should animate the previous item in', (tester) async {
        final host = _TransitionHost();
        await host.mount(tester, lazy: lazy);
        await host.position(tester, 1);
        await host.position(tester, .75);
        expect((host.incoming[0], host.outgoing[1]), ((.25, true), (.25, true)));
      });

      testWidgets('when crossing the origin, it should select the other incoming item', (tester) async {
        final host = _TransitionHost();
        await host.mount(tester, lazy: lazy);
        await host.position(tester, 1);
        await host.position(tester, 1.5);
        await host.position(tester, .75);
        expect((host.incoming[0], host.outgoing[1]), ((.25, true), (.25, true)));
      });

      testWidgets('when a controller transition settles, it should restore resting values', (tester) async {
        final host = _TransitionHost();
        await host.mount(tester, lazy: lazy);
        final next = host.controller.next();
        await tester.pumpAndSettle();
        await next;
        expect((host.incoming[1], host.outgoing[1]), ((1.0, false), (0.0, false)));
      });

      testWidgets('when a controller transition is halfway, it should follow scroll position', (tester) async {
        final host = _TransitionHost();
        await host.mount(tester, lazy: lazy);
        final next = host.controller.next();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final value = host.incoming[1]?.$1;
        await tester.pumpAndSettle();
        await next;
        expect(value, closeTo(.5, .001));
      });

      testWidgets('when a drag is cancelled, it should rewind both effects to rest', (tester) async {
        final host = _TransitionHost();
        await host.mount(tester, lazy: lazy);
        final gesture = await tester.startGesture(tester.getCenter(find.byType(SnapList)));
        await gesture.moveBy(const Offset(0, -30));
        await gesture.moveBy(const Offset(0, -100));
        await tester.pump();
        final dragged = host.incoming[1]!.$1;
        await gesture.cancel();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final returning = host.incoming[1]!;
        await tester.pumpAndSettle();
        expect(
          (dragged > 0, returning.$1 > 0 && returning.$1 < dragged, returning.$2, host.outgoing[0]),
          (true, true, false, (0.0, false)),
        );
      });

      testWidgets('when a new drag interrupts snapping, it should keep the current effect progress', (tester) async {
        final host = _TransitionHost();
        await host.mount(tester, lazy: lazy);
        final next = host.controller.next();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final before = host.incoming[1];
        final gesture = await tester.startGesture(tester.getCenter(find.byType(SnapList)));
        await gesture.moveBy(const Offset(0, 25));
        await tester.pump();
        final after = host.incoming[1];
        await gesture.cancel();
        await tester.pumpAndSettle();
        await next;
        expect(after, (before!.$1 - 25 / 400, false));
      });

      testWidgets('when reduced motion turns on during a swipe, it should restore appearance in the same frame', (
        tester,
      ) async {
        final host = _TransitionHost();
        await host.mount(tester, lazy: lazy);
        await host.position(tester, .5);
        await host.mount(tester, lazy: lazy, reducedMotion: true, settle: false);
        expect((host.incoming[0], host.outgoing[0]), ((1.0, false), (0.0, false)));
      });

      testWidgets('when reduced motion is enabled, it should use only resting appearance', (tester) async {
        final host = _TransitionHost();
        await host.mount(tester, lazy: lazy, reducedMotion: true);
        await host.position(tester, .5);
        expect((host.incoming[0], host.outgoing[0]), ((1.0, false), (0.0, false)));
      });
    });
  }

  testWidgets('when horizontal RTL navigates backward with spacing, it should keep logical direction', (tester) async {
    final host = _TransitionHost();
    await host.mount(tester, axis: Axis.horizontal, direction: TextDirection.rtl, spacing: 20);
    await host.position(tester, 1);
    await host.position(tester, .5);
    expect((host.incoming[0], host.outgoing[1]), ((.5, true), (.5, true)));
  });

  testWidgets('when a large eager list moves, it should avoid rebuilding effects or item content', (tester) async {
    final host = _TransitionHost();
    await host.mount(tester, count: 1000);
    await host.position(tester, .25);
    final initial = (host.builds, host.effects);
    await host.position(tester, .5);
    expect((host.builds - initial.$1, host.effects - initial.$2), (0, 0));
  });

  testWidgets('when trailing content reveals and returns, it should use the supplied item transitions', (tester) async {
    final host = _TransitionHost();
    await host.mount(tester, count: 1, trailingBuilder: (_) => const SizedBox(key: ValueKey(1), height: 100));
    final next = host.controller.next();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final arriving = (host.incoming[1], host.outgoing[0]);
    await tester.pumpAndSettle();
    await next;
    final settled = (host.incoming[1], host.outgoing[0]);
    final previous = host.controller.previous();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final leaving = (host.incoming[0], host.outgoing[1]);
    await tester.pumpAndSettle();
    await previous;
    expect(
      [arriving, settled, leaving],
      [((.5, false), (.5, false)), ((1.0, false), (1.0, false)), ((.5, true), (.5, true))],
    );
  });

  testWidgets('when the trailer first mounts, it should start its supplied incoming effect before measurement', (
    tester,
  ) async {
    final initialProgress = <double>[];
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(
          clipBehavior: Clip.none,
          incomingTransitionBuilder: (_, progress, details, child) {
            if (child.key == const ValueKey('trailer')) initialProgress.add(progress.value);
            return FadeTransition(opacity: progress, child: child);
          },
          trailingBuilder: (_) => const SizedBox(key: ValueKey('trailer'), height: 100),
          children: const [SizedBox.expand()],
        ),
      ),
    );
    expect(initialProgress, [0.0]);
  });

  for (final enabled in [(true, false), (false, true), (true, true), (false, false)]) {
    testWidgets('when trailing builders are $enabled, it should apply only those effects over its measured reveal', (
      tester,
    ) async {
      final host = _TransitionHost();
      await host.mount(
        tester,
        count: 1,
        withIncoming: enabled.$1,
        withOutgoing: enabled.$2,
        trailingBuilder: (_) => const SizedBox(key: ValueKey(1), height: 200),
      );
      await host.position(tester, .25);
      expect((host.incoming[1], host.outgoing[0]), (enabled.$1 ? (.5, false) : null, enabled.$2 ? (.5, false) : null));
    });
  }

  testWidgets('when a trailing reveal is cancelled, it should rewind the supplied effects without rebuilding content', (
    tester,
  ) async {
    final host = _TransitionHost();
    await host.mount(tester, count: 1, trailingBuilder: (_) => const SizedBox(key: ValueKey(1), height: 100));
    await host.position(tester, .125);
    final effects = host.effects;
    final builds = host.builds;
    await host.position(tester, .0625);
    final returning = (host.incoming[1], host.outgoing[0]);
    final rewindEffects = host.effects - effects;
    await host.position(tester, 0);
    expect(
      (returning, host.outgoing[0], rewindEffects, host.builds - builds),
      (((.25, false), (.25, false)), (0.0, false), 0, 0),
    );
  });

  testWidgets(
    'when items append during a partial trailing reveal, it should preserve departure progress while rewinding',
    (tester) async {
      final host = _TransitionHost();
      await host.mount(tester, count: 1, trailingBuilder: (_) => const SizedBox(key: ValueKey(-1), height: 100));
      await host.position(tester, .125);
      final before = host.outgoing[0];
      await host.mount(
        tester,
        count: 2,
        settle: false,
        trailingBuilder: (_) => const SizedBox(key: ValueKey(-1), height: 100),
      );
      final after = host.outgoing[0];
      await host.position(tester, .0625);
      final rewinding = host.outgoing[0];
      await host.position(tester, 0);
      expect([before, after, rewinding, host.outgoing[0]], [(.5, false), (.5, false), (.25, false), (0.0, false)]);
    },
  );

  testWidgets('when reduced motion reveals trailing content, it should use resting effects for both children', (
    tester,
  ) async {
    final host = _TransitionHost();
    await host.mount(
      tester,
      count: 1,
      reducedMotion: true,
      trailingBuilder: (_) => const SizedBox(key: ValueKey(1), height: 100),
    );
    final next = host.controller.next();
    await tester.pumpAndSettle();
    await next;
    expect((host.incoming[1], host.outgoing[0]), ((1.0, false), (0.0, false)));
  });

  testWidgets('when ticker mode disables during a cancelled drag, it should restore resting effects', (tester) async {
    final host = _TransitionHost();
    final tickerEnabled = ValueNotifier<bool>(true);
    addTearDown(tickerEnabled.dispose);
    await tester.pumpWidget(
      SnapListTestHost.app(
        ValueListenableBuilder<bool>(
          valueListenable: tickerEnabled,
          builder: (_, enabled, child) => TickerMode(enabled: enabled, child: child!),
          child: SnapList(
            controller: host.controller,
            duration: const Duration(milliseconds: 400),
            incomingTransitionBuilder: host._incoming,
            outgoingTransitionBuilder: host._outgoing,
            children: List.generate(4, host._item),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SnapList)));
    await gesture.moveBy(const Offset(0, -100));
    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tickerEnabled.value = false;
    await tester.pump();
    await tester.pump();
    expect(
      (host.controller.position, host.controller.index, host.controller.isMoving, host.incoming[0], host.outgoing[0]),
      (0, 0, false, (1.0, false), (0.0, false)),
    );
  });
}
