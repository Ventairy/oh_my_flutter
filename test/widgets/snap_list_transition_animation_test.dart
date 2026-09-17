import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'snap_list_test.dart' show SnapListTestHost;

class _AnimationHost {
  final animations = <int, Animation<double>>{};
  final outgoing = <int, Animation<double>>{};
  int builds = 0;

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(
          incomingTransitionBuilder: (_, animation, isReverse, child) {
            builds++;
            animations[(child.key! as ValueKey<int>).value] = animation;
            return FadeTransition(opacity: animation, child: child);
          },
          outgoingTransitionBuilder: (_, animation, isReverse, child) {
            outgoing[(child.key! as ValueKey<int>).value] = animation;
            return ScaleTransition(
              key: child.key,
              scale: Tween<double>(begin: 1, end: .9).animate(animation),
              child: child,
            );
          },
          children: List.generate(3, (index) => SizedBox.expand(key: ValueKey(index))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> move(WidgetTester tester, double position) async {
    tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(position * 400);
    await tester.pump();
  }
}

void main() {
  testWidgets('when progress changes, it should notify listeners without rebuilding builders', (tester) async {
    final host = _AnimationHost();
    await host.mount(tester);
    final values = <double>[];
    host.animations[1]!.addListener(() => values.add(host.animations[1]!.value));
    final builds = host.builds;
    await host.move(tester, .25);
    await host.move(tester, .5);
    expect(
      [values, host.builds - builds],
      [
        [.25, .5],
        0,
      ],
    );
  });

  testWidgets('when direction changes, it should retain animation identity', (tester) async {
    final host = _AnimationHost();
    await host.mount(tester);
    final animation = host.animations[1];
    await host.move(tester, .5);
    await host.move(tester, 1);
    await host.move(tester, 2);
    await host.move(tester, 1.5);
    expect(host.animations[1], same(animation));
  });

  testWidgets('when progress rewinds and completes, it should report animation status changes', (tester) async {
    final host = _AnimationHost();
    await host.mount(tester);
    final statuses = <AnimationStatus>[];
    host.animations[1]!.addStatusListener(statuses.add);
    await host.move(tester, .5);
    await host.move(tester, .25);
    await host.move(tester, .75);
    await host.move(tester, 1);
    expect(statuses, [
      AnimationStatus.forward,
      AnimationStatus.reverse,
      AnimationStatus.forward,
      AnimationStatus.completed,
    ]);
  });

  testWidgets('when an outgoing effect returns to rest, it should report dismissed status', (tester) async {
    final host = _AnimationHost();
    await host.mount(tester);
    await host.move(tester, .5);
    await host.move(tester, 0);
    expect(host.outgoing[0]!.status, AnimationStatus.dismissed);
  });

  testWidgets('when a value listener removes itself, it should leave other listeners active', (tester) async {
    final host = _AnimationHost();
    await host.mount(tester);
    final animation = host.animations[1]!;
    var first = 0;
    var second = 0;
    void listener() {
      first++;
      animation.removeListener(listener);
    }

    animation
      ..addListener(listener)
      ..addListener(() => second++);
    await host.move(tester, .25);
    await host.move(tester, .5);
    expect((first, second), (1, 2));
  });

  testWidgets('when a status listener is removed, it should stop receiving changes', (tester) async {
    final host = _AnimationHost();
    await host.mount(tester);
    final animation = host.animations[1]!;
    final statuses = <AnimationStatus>[];
    animation.addStatusListener(statuses.add);
    await host.move(tester, .5);
    animation.removeStatusListener(statuses.add);
    await host.move(tester, .25);
    expect(statuses, [AnimationStatus.forward]);
  });

  testWidgets('when the list is unmounted, it should detach transition listeners cleanly', (tester) async {
    final host = _AnimationHost();
    await host.mount(tester);
    await host.move(tester, .5);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
