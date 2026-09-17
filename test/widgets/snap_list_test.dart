import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class SnapListTestHost {
  static Widget app(Widget child, {bool reducedMotion = false, TextDirection direction = TextDirection.ltr}) =>
      MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: Scaffold(
              body: Center(child: SizedBox(width: 300, height: 400, child: child)),
            ),
          ),
        ),
      );

  static List<Widget> cards(int count) => List.generate(
    count,
    (index) => ColoredBox(
      key: ValueKey(index),
      color: Colors.blue,
      child: Center(child: Text('Item $index')),
    ),
  );
}

void main() {
  test('when using default motion, it should use neutral linear curves on both constructors', () {
    const eager = SnapList(children: []);
    final lazy = SnapList.builder(itemCount: 0, itemBuilder: (_, _) => const SizedBox());
    expect(
      (eager.curve, eager.reverseCurve, lazy.curve, lazy.reverseCurve),
      (Curves.linear, Curves.linear, Curves.linear, Curves.linear),
    );
  });
  for (final lazy in [false, true]) {
    for (final overrideReverse in [false, true]) {
      test(
        'when reverse motion is ${overrideReverse ? "explicit" : "omitted"} on lazy=$lazy, it should resolve return settings',
        () {
          const duration = Duration(milliseconds: 400);
          const reverseDuration = Duration(milliseconds: 100);
          final list = lazy
              ? SnapList.builder(
                  itemCount: 0,
                  itemBuilder: (_, _) => const SizedBox(),
                  duration: duration,
                  curve: Curves.easeIn,
                  reverseDuration: overrideReverse ? reverseDuration : null,
                  reverseCurve: overrideReverse ? Curves.easeOut : null,
                )
              : SnapList(
                  duration: duration,
                  curve: Curves.easeIn,
                  reverseDuration: overrideReverse ? reverseDuration : null,
                  reverseCurve: overrideReverse ? Curves.easeOut : null,
                  children: const [],
                );
          expect(
            (list.reverseDuration, list.reverseCurve),
            overrideReverse ? (reverseDuration, Curves.easeOut) : (duration, Curves.easeIn),
          );
        },
      );
    }
  }
  test('when the commit threshold is invalid, it should reject the configuration', () {
    expect(() => SnapList(commitThreshold: 2, children: const []), throwsAssertionError);
  });

  testWidgets('when navigating forward and back, it should use the corresponding curve and duration', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(
          controller: controller,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeIn,
          reverseDuration: const Duration(milliseconds: 600),
          reverseCurve: Curves.easeOut,
          children: SnapListTestHost.cards(3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final next = controller.next();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final forwardPosition = controller.position;
    await tester.pumpAndSettle();
    await next;
    final previous = controller.previous();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final backwardPosition = controller.position;
    await tester.pumpAndSettle();
    await previous;
    expect(
      [forwardPosition, backwardPosition],
      [closeTo(Curves.easeIn.transform(.5), .0001), closeTo(1 - Curves.easeOut.transform(1 / 3), .0001)],
    );
  });

  testWidgets('when swiping to the previous item, it should use reverse motion', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(
          controller: controller,
          duration: const Duration(milliseconds: 100),
          reverseDuration: const Duration(milliseconds: 400),
          reverseCurve: Curves.easeIn,
          children: SnapListTestHost.cards(3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final next = controller.next();
    await tester.pumpAndSettle();
    await next;
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SnapList)));
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump(const Duration(milliseconds: 500));
    final dragged = controller.position!;
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final returning = controller.position;
    await tester.pumpAndSettle();
    expect([returning, controller.index], [closeTo(dragged * (1 - Curves.easeIn.transform(.5)), .0001), 0]);
  });

  testWidgets('when a drag is cancelled, it should use the reverse curve and duration', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(
          controller: controller,
          duration: const Duration(milliseconds: 100),
          curve: Curves.linear,
          reverseDuration: const Duration(milliseconds: 400),
          reverseCurve: Curves.easeIn,
          children: SnapListTestHost.cards(3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SnapList)));
    await gesture.moveBy(const Offset(0, -100));
    final dragged = controller.position!;
    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final returning = controller.position;
    await tester.pumpAndSettle();
    expect([returning, controller.position], [closeTo(dragged * (1 - Curves.easeIn.transform(.5)), .0001), 0]);
  });

  for (final axis in Axis.values) {
    testWidgets('when dragged forward on $axis, it should advance one item', (tester) async {
      final controller = SnapListController();
      await tester.pumpWidget(
        SnapListTestHost.app(
          SnapList(axis: axis, controller: controller, children: SnapListTestHost.cards(4)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(SnapList), axis == Axis.vertical ? const Offset(0, -250) : const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
    });
  }

  testWidgets('when using spacing, it should keep items the size of the viewport', (tester) async {
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(axis: Axis.horizontal, spacing: 10, children: SnapListTestHost.cards(4)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey(0)).last), const Rect.fromLTWH(250, 100, 300, 400));
  });

  testWidgets('when next is requested, it should complete only after settling', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(SnapList(controller: controller, children: SnapListTestHost.cards(4))),
    );
    await tester.pumpAndSettle();
    final result = controller.next();
    await tester.pumpAndSettle();
    expect((await result, controller.index), (true, 1));
  });

  testWidgets('when a controller request is replaced, it should complete the first as interrupted', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(SnapList(controller: controller, children: SnapListTestHost.cards(4))),
    );
    await tester.pumpAndSettle();
    final first = controller.next();
    await tester.pump(const Duration(milliseconds: 40));
    final second = controller.next();
    await tester.pumpAndSettle();
    expect((await first, await second, controller.index), (false, true, 1));
  });

  testWidgets('when a lazy list has many items, it should build only nearby children', (tester) async {
    var builds = 0;
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList.builder(
          itemCount: 10000,
          itemBuilder: (_, index) {
            builds++;
            return Text('Item $index');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(builds, lessThanOrEqualTo(3));
  });

  testWidgets('when all children are supplied, it should mount every child', (tester) async {
    await tester.pumpWidget(SnapListTestHost.app(SnapList(children: SnapListTestHost.cards(10))));
    await tester.pumpAndSettle();
    expect(
      find.byType(ColoredBox, skipOffstage: false).evaluate().where((e) => e.widget.key is ValueKey<int>).length,
      10,
    );
  });

  testWidgets('when motion is reduced, it should navigate without intermediate travel', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(SnapList(controller: controller, children: SnapListTestHost.cards(3)), reducedMotion: true),
    );
    await tester.pumpAndSettle();
    final result = controller.next();
    await tester.pump();
    expect((await result, controller.position), (true, 1));
  });

  testWidgets('when a drag is cancelled, it should return without committing', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(SnapList(controller: controller, children: SnapListTestHost.cards(3))),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SnapList)));
    await gesture.moveBy(const Offset(0, -200));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect((controller.position, controller.index), (0, 0));
  });

  testWidgets('when an empty list is shown, it should have no selected item', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(SnapListTestHost.app(SnapList(controller: controller, children: const [])));
    await tester.pumpAndSettle();
    expect((controller.position, await controller.next()), (null, false));
  });

  testWidgets('when wheel events form a burst, it should move at most one item', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(SnapList(controller: controller, children: SnapListTestHost.cards(4))),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(position: tester.getCenter(find.byType(SnapList)), scrollDelta: const Offset(0, 300)),
      );
    }
    await tester.pump(const Duration(milliseconds: 121));
    await tester.pumpAndSettle();
    expect(controller.index, 1);
  });
}
