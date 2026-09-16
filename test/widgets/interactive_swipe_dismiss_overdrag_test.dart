import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  const key = ValueKey('overdrag-child');
  Widget app({
    void Function(Offset)? onOverdrag,
    bool freeDrag = false,
    bool reducedMotion = false,
    bool handle = false,
    double sensitivity = 1,
    double dismissFraction = 0.5,
    InteractiveSwipeDismissDirection direction = InteractiveSwipeDismissDirection.down,
    bool Function()? onDismiss,
    Widget child = const ColoredBox(color: Colors.white),
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: const Size(800, 600), disableAnimations: reducedMotion),
      child: Center(
        child: SizedBox(
          width: 300,
          height: 300,
          child: InteractiveSwipeDismiss(
            direction: direction,
            onOverdrag: onOverdrag,
            dragConfig: InteractiveSwipeDismissDragConfig(
              freeDrag: freeDrag,
              sensitivity: sensitivity,
              dismissFraction: dismissFraction,
              returnDuration: const Duration(milliseconds: 200),
            ),
            onDismiss: onDismiss ?? () => false,
            child: SizedBox.expand(
              key: key,
              child: handle ? InteractiveSwipeDismissHandle(child: child) : child,
            ),
          ),
        ),
      ),
    ),
  );

  for (final handle in [false, true]) {
    for (final (direction, drag, excess, movement) in [
      (InteractiveSwipeDismissDirection.down, const Offset(-80, -120), const Offset(-80, -120), Offset.zero),
      (InteractiveSwipeDismissDirection.up, const Offset(80, 120), const Offset(80, 120), Offset.zero),
      (InteractiveSwipeDismissDirection.left, const Offset(120, -80), const Offset(120, -80), Offset.zero),
      (InteractiveSwipeDismissDirection.right, const Offset(-120, 80), const Offset(-120, 80), Offset.zero),
      (InteractiveSwipeDismissDirection.down, const Offset(80, 120), const Offset(80, 0), const Offset(0, 120)),
      (InteractiveSwipeDismissDirection.down, const Offset(-120, 0), const Offset(-120, 0), Offset.zero),
      (InteractiveSwipeDismissDirection.down, const Offset(120, 0), const Offset(120, 0), Offset.zero),
    ]) {
      testWidgets(
        'when dragging $drag for $direction with handle $handle, it should report excess without translating it',
        (tester) async {
          final reports = <Offset>[];
          await tester.pumpWidget(app(direction: direction, handle: handle, onOverdrag: reports.add));
          final initial = tester.getTopLeft(find.byKey(key));
          final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
          await gesture.moveBy(drag);
          await tester.pump();
          final displacement = tester.getTopLeft(find.byKey(key)) - initial;
          await gesture.cancel();
          await tester.pumpAndSettle();
          expect(
            [reports, displacement],
            [
              [excess, Offset.zero],
              movement,
            ],
          );
        },
      );
    }
  }

  testWidgets('when crossing rest repeatedly, it should report total restricted displacement and clear it', (
    tester,
  ) async {
    final reports = <Offset>[];
    await tester.pumpWidget(app(onOverdrag: reports.add));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    for (final delta in [const Offset(0, 100), const Offset(0, -60), const Offset(-20, -60), const Offset(20, 60)]) {
      await gesture.moveBy(delta);
      await tester.pump();
    }
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(reports, [const Offset(-20, -20), Offset.zero]);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets('when sensitivity changes with reduced motion $reducedMotion, it should still report raw input', (
      tester,
    ) async {
      final reports = <Offset>[];
      await tester.pumpWidget(app(sensitivity: 0.2, reducedMotion: reducedMotion, onOverdrag: reports.add));
      final initial = tester.getTopLeft(find.byKey(key));
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
      await gesture.moveBy(const Offset(-80, -120));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        [reports, tester.getTopLeft(find.byKey(key))],
        [
          [const Offset(-80, -120), Offset.zero],
          initial,
        ],
      );
    });
  }

  testWidgets('when freeDrag is enabled, it should move freely without reporting overdrag', (tester) async {
    final reports = <Offset>[];
    await tester.pumpWidget(app(freeDrag: true, onOverdrag: reports.add));
    final initial = tester.getTopLeft(find.byKey(key));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(0, 40));
    await gesture.moveBy(const Offset(-80, -120));
    await tester.pump();
    final displacement = tester.getTopLeft(find.byKey(key)) - initial;
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect([reports, displacement], [isEmpty, const Offset(-80, -80)]);
  });

  testWidgets(
    'when the callback changes mid-gesture, it should clear the captured callback before using the next one',
    (tester) async {
      final first = <Offset>[];
      final next = <Offset>[];
      await tester.pumpWidget(app(onOverdrag: first.add));
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
      await tester.pumpWidget(app(onOverdrag: next.add));
      await gesture.moveBy(const Offset(-40, -20));
      await gesture.cancel();
      await tester.pumpAndSettle();
      final second = await tester.startGesture(tester.getCenter(find.byKey(key)));
      await second.moveBy(const Offset(40, -20));
      await second.cancel();
      await tester.pumpAndSettle();
      expect(
        [first, next],
        [
          [const Offset(-40, -20), Offset.zero],
          [const Offset(40, -20), Offset.zero],
        ],
      );
    },
  );

  for (final commit in [false, true]) {
    testWidgets('when release commits $commit, it should clear notifications without animating reported input', (
      tester,
    ) async {
      final reports = <Offset>[];
      var dismissals = 0;
      await tester.pumpWidget(
        app(
          onOverdrag: reports.add,
          dismissFraction: 0,
          onDismiss: () {
            dismissals++;
            return false;
          },
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
      if (commit) await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(Offset(-40, commit ? -100 : -80));
      if (commit) await gesture.moveBy(const Offset(0, 100));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        [reports, dismissals],
        [
          [const Offset(-40, -80), if (commit) const Offset(-40, 0), Offset.zero],
          if (commit) 1 else 0,
        ],
      );
    });
  }

  testWidgets('when only allowed movement changes, it should not repeat the same overdrag report', (tester) async {
    final reports = <Offset>[];
    await tester.pumpWidget(app(onOverdrag: reports.add));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(-20, 40));
    await gesture.moveBy(const Offset(0, 20));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(reports, [const Offset(-20, 0), Offset.zero]);
  });

  for (final axis in [Axis.vertical, Axis.horizontal]) {
    for (final reverse in [false, true]) {
      for (final atBoundary in [false, true]) {
        testWidgets(
          'when pulling $axis over reverse $reverse content at boundary $atBoundary, it should report only unconsumed input',
          (tester) async {
            final reports = <Offset>[];
            final controller = ScrollController();
            addTearDown(controller.dispose);
            await tester.pumpWidget(
              app(
                onOverdrag: reports.add,
                child: ListView.builder(
                  controller: controller,
                  scrollDirection: axis,
                  reverse: reverse,
                  physics: const ClampingScrollPhysics(),
                  itemExtent: 100,
                  itemCount: 30,
                  itemBuilder: (_, index) => Text('$index'),
                ),
              ),
            );
            controller.jumpTo(atBoundary ? (reverse ? 0 : controller.position.maxScrollExtent) : 200);
            await tester.pump();
            final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
            final delta = axis == Axis.vertical ? const Offset(0, -60) : const Offset(-60, 0);
            await gesture.moveBy(delta);
            await tester.pump();
            await gesture.cancel();
            await tester.pumpAndSettle();
            expect(reports, atBoundary ? [delta, Offset.zero] : isEmpty);
          },
        );
      }
    }
  }

  testWidgets('when scrolling reaches its boundary, it should exclude previous scroll travel', (tester) async {
    final reports = <Offset>[];
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        onOverdrag: reports.add,
        child: ListView.builder(
          controller: controller,
          physics: const ClampingScrollPhysics(),
          itemExtent: 100,
          itemCount: 30,
          itemBuilder: (_, index) => Text('$index'),
        ),
      ),
    );
    controller.jumpTo(controller.position.maxScrollExtent - 40);
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    for (var step = 0; step < 16 && reports.isEmpty; step++) {
      await gesture.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(reports, [const Offset(0, -10), Offset.zero]);
  });
  testWidgets('when an outer scrollable can consume the pull, it should not report inner-edge overdrag', (
    tester,
  ) async {
    final outer = ScrollController();
    final inner = ScrollController();
    final reports = <Offset>[];
    addTearDown(outer.dispose);
    addTearDown(inner.dispose);
    await tester.pumpWidget(
      app(
        onOverdrag: reports.add,
        child: SingleChildScrollView(
          controller: outer,
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: ListView.builder(
                  controller: inner,
                  itemExtent: 100,
                  itemCount: 20,
                  itemBuilder: (_, index) => Text('$index'),
                ),
              ),
              const SizedBox(height: 500),
            ],
          ),
        ),
      ),
    );
    inner.jumpTo(inner.position.maxScrollExtent);
    await tester.pump();
    final gesture = await tester.startGesture(tester.getTopLeft(find.byKey(key)) + const Offset(100, 100));
    await gesture.moveBy(const Offset(0, -40));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(reports, isEmpty);
  });

  testWidgets('when a handle is dragged over scrolled content, it should report input and freeze scrolling', (
    tester,
  ) async {
    final reports = <Offset>[];
    final controller = ScrollController(initialScrollOffset: 200);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        onOverdrag: reports.add,
        handle: true,
        child: ListView.builder(
          controller: controller,
          itemExtent: 100,
          itemCount: 30,
          itemBuilder: (_, index) => Text('$index'),
        ),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(-40, -80));
    await tester.pump();
    final offset = controller.offset;
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(
      [reports, offset],
      [
        [const Offset(-40, -80), Offset.zero],
        200.0,
      ],
    );
  });

  testWidgets('when an edge cooldown expires while idle, it should resume reporting unconsumed input', (tester) async {
    final reports = <Offset>[];
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        onOverdrag: reports.add,
        child: ListView.builder(
          controller: controller,
          physics: const ClampingScrollPhysics(),
          itemExtent: 100,
          itemCount: 30,
          itemBuilder: (_, index) => Text('$index'),
        ),
      ),
    );
    controller.jumpTo(controller.position.maxScrollExtent - 100);
    await tester.pump();
    final animation = controller.animateTo(
      controller.position.maxScrollExtent,
      duration: const Duration(milliseconds: 20),
      curve: Curves.linear,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 21));
    await animation;
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    final blockedCount = reports.length;
    await tester.pump(const Duration(milliseconds: 130));
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(
      [blockedCount, reports],
      [
        0,
        [const Offset(0, -20), Offset.zero],
      ],
    );
  });
  testWidgets('when a callback is added during a gesture, it should report only from the next gesture', (tester) async {
    final reports = <Offset>[];
    await tester.pumpWidget(app());
    final first = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await tester.pumpWidget(app(onOverdrag: reports.add));
    await first.moveBy(const Offset(-40, -20));
    await first.cancel();
    await tester.pumpAndSettle();
    final second = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await second.moveBy(const Offset(40, -20));
    await second.cancel();
    await tester.pumpAndSettle();
    expect(reports, [const Offset(40, -20), Offset.zero]);
  });

  testWidgets('when a callback is removed during a gesture, it should still clear the captured callback', (
    tester,
  ) async {
    final reports = <Offset>[];
    await tester.pumpWidget(app(onOverdrag: reports.add));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(-40, -20));
    await tester.pumpWidget(app());
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(reports, [const Offset(-40, -20), Offset.zero]);
  });
  for (final handle in [false, true]) {
    for (final (direction, forward, sideways) in [
      (InteractiveSwipeDismissDirection.down, const Offset(0, 1), const Offset(-1, 0)),
      (InteractiveSwipeDismissDirection.up, const Offset(0, -1), const Offset(1, 0)),
      (InteractiveSwipeDismissDirection.left, const Offset(-1, 0), const Offset(0, -1)),
      (InteractiveSwipeDismissDirection.right, const Offset(1, 0), const Offset(0, 1)),
    ]) {
      for (final opposite in [false, true]) {
        testWidgets(
          'when a handle $handle starts outside $direction with opposite $opposite, it should not become a dismissal',
          (tester) async {
            var dismissals = 0;
            final reports = <Offset>[];
            await tester.pumpWidget(
              app(
                direction: direction,
                handle: handle,
                onOverdrag: reports.add,
                onDismiss: () {
                  dismissals++;
                  return false;
                },
              ),
            );
            final initial = tester.getTopLeft(find.byKey(key));
            final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
            await gesture.moveBy((opposite ? -forward : sideways) * 40);
            await gesture.moveBy(forward * 240);
            await tester.pump();
            final displacement = tester.getTopLeft(find.byKey(key)) - initial;
            await gesture.up();
            await tester.pumpAndSettle();
            final firstOffset = (opposite ? -forward : sideways) * 40;
            expect(
              [dismissals, displacement, reports],
              [
                0,
                Offset.zero,
                [firstOffset, firstOffset + forward * 240, Offset.zero],
              ],
            );
          },
        );
      }
    }
  }

  testWidgets('when the finger lifts after a rejected start, it should allow a fresh downward dismissal', (
    tester,
  ) async {
    var dismissals = 0;
    await tester.pumpWidget(
      app(
        onOverdrag: (_) {},
        onDismiss: () {
          dismissals++;
          return false;
        },
      ),
    );
    final first = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await first.moveBy(const Offset(-40, 0));
    await first.moveBy(const Offset(0, 200));
    await first.up();
    await tester.pumpAndSettle();
    final firstCount = dismissals;
    final second = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await second.moveBy(const Offset(0, 200));
    await second.up();
    await tester.pumpAndSettle();
    expect([firstCount, dismissals], [0, 1]);
  });
  testWidgets('when initial sideways movement stays below activation, it should allow a downward dismissal', (
    tester,
  ) async {
    var dismissals = 0;
    await tester.pumpWidget(
      app(
        onOverdrag: (_) {},
        onDismiss: () {
          dismissals++;
          return false;
        },
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(-3, 0));
    await gesture.moveBy(const Offset(0, 160));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(dismissals, 1);
  });

  testWidgets('when a sideways start becomes a fast downward fling, it should remain ineligible', (tester) async {
    var dismissals = 0;
    await tester.pumpWidget(
      app(
        onOverdrag: (_) {},
        onDismiss: () {
          dismissals++;
          return false;
        },
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(-20, 0), timeStamp: const Duration(milliseconds: 10));
    await gesture.moveBy(const Offset(0, 30), timeStamp: const Duration(milliseconds: 20));
    await gesture.moveBy(const Offset(0, 30), timeStamp: const Duration(milliseconds: 30));
    await gesture.up(timeStamp: const Duration(milliseconds: 31));
    await tester.pumpAndSettle();
    expect(dismissals, 0);
  });
}
