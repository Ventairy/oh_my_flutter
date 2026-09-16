import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  const childKey = ValueKey('sized-child');
  Widget app({
    required bool Function() onDismiss,
    Size size = const Size(200, 200),
    InteractiveSwipeDismissDirection direction = InteractiveSwipeDismissDirection.down,
    double sensitivity = 1,
    bool handle = false,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    const content = ColoredBox(key: childKey, color: Colors.white);
    return MaterialApp(
      home: Center(
        child: SizedBox.fromSize(
          size: size,
          child: InteractiveSwipeDismiss(
            direction: direction,
            dragConfig: InteractiveSwipeDismissDragConfig(
              dismissFraction: 0.5,
              sensitivity: sensitivity,
              returnDuration: Duration.zero,
            ),
            onDismiss: onDismiss,
            child: Padding(
              padding: padding,
              child: handle ? const InteractiveSwipeDismissHandle(child: content) : content,
            ),
          ),
        ),
      ),
    );
  }

  for (final (direction, vector) in [
    (InteractiveSwipeDismissDirection.down, const Offset(0, 1)),
    (InteractiveSwipeDismissDirection.up, const Offset(0, -1)),
    (InteractiveSwipeDismissDirection.left, const Offset(-1, 0)),
    (InteractiveSwipeDismissDirection.right, const Offset(1, 0)),
  ]) {
    for (final distance in [99.0, 100.0, 101.0]) {
      testWidgets('when dragging $distance pixels $direction, it should use half the child extent', (tester) async {
        var dismissals = 0;
        await tester.pumpWidget(
          app(
            direction: direction,
            size: vector.dy == 0 ? const Size(200, 320) : const Size(320, 200),
            onDismiss: () {
              dismissals++;
              return false;
            },
          ),
        );
        final gesture = await tester.startGesture(tester.getCenter(find.byKey(childKey)));
        await gesture.moveBy(vector * distance);
        await tester.pump(const Duration(milliseconds: 500));
        await gesture.up();
        await tester.pump();
        expect(dismissals, distance >= 100 ? 1 : 0);
      });
    }
  }

  for (final distance in [75.0, 100.0]) {
    testWidgets('when a padded child handle moves $distance pixels, it should use the entire child size', (
      tester,
    ) async {
      var dismissals = 0;
      await tester.pumpWidget(
        app(
          handle: true,
          padding: const EdgeInsets.all(40),
          onDismiss: () {
            dismissals++;
            return false;
          },
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(childKey)));
      await gesture.moveBy(Offset(0, distance));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pump();
      expect(dismissals, distance >= 100 ? 1 : 0);
    });
  }

  testWidgets('when sensitivity reduces travel, it should still commit using finger distance', (tester) async {
    var dismissals = 0;
    await tester.pumpWidget(
      app(
        sensitivity: 0.2,
        onDismiss: () {
          dismissals++;
          return false;
        },
      ),
    );
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(childKey)));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pump();
    expect(dismissals, 1);
  });

  testWidgets('when the child resizes during a gesture, it should use the new size only on the next gesture', (
    tester,
  ) async {
    var dismissals = 0;
    bool dismiss() {
      dismissals++;
      return false;
    }

    await tester.pumpWidget(app(onDismiss: dismiss));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(childKey)));
    await tester.pumpWidget(app(size: const Size(200, 400), onDismiss: dismiss));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pump();
    final firstCount = dismissals;
    final nextGesture = await tester.startGesture(tester.getCenter(find.byKey(childKey)));
    await nextGesture.moveBy(const Offset(0, 100));
    await tester.pump(const Duration(milliseconds: 500));
    await nextGesture.up();
    await tester.pump();
    expect((firstCount, dismissals), (1, 1));
  });
}
