import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  const key = ValueKey('position-child');
  Widget app({
    void Function(Offset, double)? onPositionChanged,
    bool freeDrag = false,
    bool reducedMotion = false,
    bool handle = false,
    double sensitivity = 1,
    Size size = const Size(300, 300),
    Duration returnDuration = const Duration(milliseconds: 200),
    InteractiveSwipeDismissDirection direction = InteractiveSwipeDismissDirection.down,
    FutureOr<bool> Function()? onDismiss,
    Widget child = const ColoredBox(color: Colors.white),
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: const Size(800, 600), disableAnimations: reducedMotion),
      child: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: InteractiveSwipeDismiss(
            direction: direction,
            onPositionChanged: onPositionChanged,
            dragConfig: InteractiveSwipeDismissDragConfig(
              freeDrag: freeDrag,
              sensitivity: sensitivity,
              returnDuration: returnDuration,
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
    for (final (direction, delta, expected) in [
      (InteractiveSwipeDismissDirection.down, const Offset(10, 40), const Offset(0, 20)),
      (InteractiveSwipeDismissDirection.up, const Offset(10, -40), const Offset(0, -20)),
      (InteractiveSwipeDismissDirection.left, const Offset(-40, 10), const Offset(-20, 0)),
      (InteractiveSwipeDismissDirection.right, const Offset(40, 10), const Offset(20, 0)),
    ]) {
      testWidgets('when moving $direction with handle $handle, it should report each applied offset before a frame', (
        tester,
      ) async {
        final reports = <Offset>[];
        await tester.pumpWidget(
          app(
            onPositionChanged: (offset, _) => reports.add(offset),
            direction: direction,
            handle: handle,
            sensitivity: 0.5,
          ),
        );
        final initial = tester.getTopLeft(find.byKey(key));
        final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
        await gesture.moveBy(delta);
        await gesture.moveBy(delta);
        await gesture.moveBy(delta);
        final synchronousReports = List<Offset>.of(reports);
        await tester.pump();
        final displacement = tester.getTopLeft(find.byKey(key)) - initial;
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(
          [synchronousReports, displacement],
          [
            [expected, expected * 2, expected * 3],
            expected * 3,
          ],
        );
      });
    }
  }

  testWidgets('when free dragging, it should report both scaled axes', (tester) async {
    final reports = <Offset>[];
    await tester.pumpWidget(
      app(onPositionChanged: (offset, _) => reports.add(offset), freeDrag: true, sensitivity: 0.5),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(20, 40));
    final result = List<Offset>.of(reports);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(result, [const Offset(10, 20)]);
  });

  testWidgets('when cancelling, it should report every return update and one final zero', (tester) async {
    final reports = <Offset>[];
    await tester.pumpWidget(app(onPositionChanged: (offset, _) => reports.add(offset)));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(0, 80));
    await gesture.cancel();
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(reports, [
      const Offset(0, 80),
      const Offset(0, 60),
      const Offset(0, 40),
      offsetMoreOrLessEquals(const Offset(0, 20)),
      Offset.zero,
    ]);
  });

  testWidgets('when return duration is zero, it should synchronously report the reset once', (tester) async {
    final reports = <Offset>[];
    await tester.pumpWidget(app(onPositionChanged: (offset, _) => reports.add(offset), returnDuration: Duration.zero));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(0, 80));
    await gesture.cancel();
    expect(reports, [const Offset(0, 80), Offset.zero]);
  });

  for (final accepted in [false, true]) {
    testWidgets('when async dismissal is accepted $accepted, it should report only actual subsequent movement', (
      tester,
    ) async {
      final reports = <Offset>[];
      final dismissal = Completer<bool>();
      await tester.pumpWidget(
        app(onPositionChanged: (offset, _) => reports.add(offset), onDismiss: () => dismissal.future),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
      await gesture.moveBy(const Offset(0, 200));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      final pending = List<Offset>.of(reports);
      dismissal.complete(accepted);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(
        [pending, reports],
        [
          [const Offset(0, 200)],
          if (accepted) [const Offset(0, 200)] else [const Offset(0, 200), const Offset(0, 100), Offset.zero],
        ],
      );
    });
  }

  testWidgets('when translation is constrained or repeated, it should omit unchanged positions', (tester) async {
    final reports = <Offset>[];
    await tester.pumpWidget(app(onPositionChanged: (offset, _) => reports.add(offset)));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(0, 40));
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(0, -80));
    await gesture.moveBy(const Offset(0, -20));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(reports, [const Offset(0, 40), Offset.zero]);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets('when no translation occurs with reduced motion $reducedMotion, it should remain silent', (
      tester,
    ) async {
      final reports = <Offset>[];
      await tester.pumpWidget(app(onPositionChanged: (offset, _) => reports.add(offset), reducedMotion: reducedMotion));
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
      await gesture.moveBy(reducedMotion ? const Offset(0, 80) : const Offset(0, -80));
      await gesture.cancel();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(reports, isEmpty);
    });
  }

  testWidgets('when scrolling away from the dismissal edge, it should not report a position change', (tester) async {
    final reports = <Offset>[];
    final controller = ScrollController(initialScrollOffset: 300);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      app(
        onPositionChanged: (offset, _) => reports.add(offset),
        child: ListView(controller: controller, children: const [SizedBox(height: 2000)]),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(0, 40));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(reports, isEmpty);
  });

  testWidgets('when disposed during return, it should stop without reporting a reset', (tester) async {
    final reports = <Offset>[];
    await tester.pumpWidget(app(onPositionChanged: (offset, _) => reports.add(offset)));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(0, 80));
    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final beforeDisposal = List<Offset>.of(reports);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(reports, beforeDisposal);
  });

  for (final returnDuration in [Duration.zero, const Duration(milliseconds: 200)]) {
    testWidgets('when replaced mid-gesture with return $returnDuration, it should switch callbacks next gesture', (
      tester,
    ) async {
      final first = <Offset>[];
      final second = <Offset>[];
      await tester.pumpWidget(app(onPositionChanged: (offset, _) => first.add(offset), returnDuration: returnDuration));
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pumpWidget(
        app(onPositionChanged: (offset, _) => second.add(offset), returnDuration: returnDuration),
      );
      await gesture.moveBy(const Offset(0, 40));
      await gesture.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      final next = await tester.startGesture(tester.getCenter(find.byKey(key)));
      await next.moveBy(const Offset(0, 40));
      await next.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(
        [first, second],
        [
          [const Offset(0, 40), const Offset(0, 80), Offset.zero],
          [const Offset(0, 40), Offset.zero],
        ],
      );
    });
  }

  for (final (direction, vector, extent) in [
    (InteractiveSwipeDismissDirection.down, const Offset(0, 1), 200.0),
    (InteractiveSwipeDismissDirection.up, const Offset(0, -1), 200.0),
    (InteractiveSwipeDismissDirection.left, const Offset(-1, 0), 100.0),
    (InteractiveSwipeDismissDirection.right, const Offset(1, 0), 100.0),
  ]) {
    testWidgets('when moving $direction beyond the child size, it should report unbounded scaled fractions', (
      tester,
    ) async {
      final reports = <double>[];
      await tester.pumpWidget(
        app(
          size: const Size(100, 200),
          direction: direction,
          sensitivity: 0.5,
          onPositionChanged: (_, fraction) => reports.add(fraction),
          returnDuration: Duration.zero,
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
      await gesture.moveBy(vector * extent);
      await gesture.moveBy(vector * extent);
      await gesture.moveBy(vector * extent * 2);
      await gesture.cancel();
      expect(reports, [0.5, 1.0, 2.0, 0.0]);
    });
  }

  testWidgets('when free dragging sideways and opposite, it should report changes even with zero fraction', (
    tester,
  ) async {
    final reports = <(Offset, double)>[];
    await tester.pumpWidget(
      app(
        size: const Size(100, 200),
        freeDrag: true,
        returnDuration: Duration.zero,
        onPositionChanged: (offset, fraction) => reports.add((offset, fraction)),
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(20, 100));
    await gesture.moveBy(const Offset(10, -100));
    await gesture.moveBy(const Offset(10, 0));
    await gesture.moveBy(const Offset(10, -100));
    await gesture.cancel();
    expect(reports, [
      (const Offset(20, 100), 0.5),
      (const Offset(30, 0), 0.0),
      (const Offset(40, 0), 0.0),
      (const Offset(50, -100), 0.0),
      (Offset.zero, 0.0),
    ]);
  });

  for (final accepted in [false, true]) {
    testWidgets('when dismissal is accepted $accepted, it should retain fractions through resolution and return', (
      tester,
    ) async {
      final reports = <double>[];
      final dismissal = Completer<bool>();
      await tester.pumpWidget(
        app(
          size: const Size(100, 200),
          onDismiss: () => dismissal.future,
          onPositionChanged: (_, fraction) => reports.add(fraction),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
      await gesture.moveBy(const Offset(0, 200));
      await gesture.up();
      await tester.pump();
      dismissal.complete(accepted);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(reports, accepted ? [1.0] : [1.0, 0.5, 0.0]);
    });
  }

  testWidgets('when size direction and callback change, it should preserve the gesture reference through return', (
    tester,
  ) async {
    final first = <double>[];
    final second = <double>[];
    await tester.pumpWidget(app(size: const Size(100, 200), onPositionChanged: (_, fraction) => first.add(fraction)));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pumpWidget(
      app(
        size: const Size(400, 300),
        direction: InteractiveSwipeDismissDirection.right,
        onPositionChanged: (_, fraction) => second.add(fraction),
      ),
    );
    await gesture.moveBy(const Offset(0, 100));
    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    final next = await tester.startGesture(tester.getCenter(find.byKey(key)));
    await next.moveBy(const Offset(200, 0));
    await next.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(
      [first, second],
      [
        [0.5, 1.0, 0.5, 0.0],
        [0.5, 0.0],
      ],
    );
  });

  testWidgets('when the captured child extent is zero, it should report zero fraction', (tester) async {
    final reports = <double>[];
    await tester.pumpWidget(
      app(size: Size.zero, returnDuration: Duration.zero, onPositionChanged: (_, fraction) => reports.add(fraction)),
    );
    // Deliver directly because a zero-sized child cannot be hit-tested.
    final listener = tester.widget<Listener>(
      find
          .descendant(
            of: find.byType(InteractiveSwipeDismiss),
            matching: find.byWidgetPredicate((widget) => widget is Listener && widget.onPointerDown != null),
          )
          .first,
    );
    listener.onPointerDown!(const PointerDownEvent(pointer: 42, position: Offset(400, 300)));
    listener.onPointerMove!(const PointerMoveEvent(pointer: 42, position: Offset(400, 400), delta: Offset(0, 100)));
    listener.onPointerCancel!(const PointerCancelEvent(pointer: 42));
    expect(reports, [0.0, 0.0]);
  });
}
