import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'snap_list_test.dart' show SnapListTestHost;

void main() {
  test('when detached, it should reject an item jump', () {
    final controller = SnapListController();
    expect(() => controller.jumpTo(0), throwsAssertionError);
    controller.dispose();
  });
  test('when detached, it should reject navigation', () async {
    final controller = SnapListController();
    expect((controller.hasClients, await controller.next(), await controller.previous()), (false, false, false));
    controller.dispose();
  });
  testWidgets('when disposed during navigation, it should resolve the request without retaining the list', (
    tester,
  ) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(SnapList(controller: controller, children: SnapListTestHost.cards(3))),
    );
    await tester.pumpAndSettle();
    final result = controller.next();
    await tester.pumpWidget(const SizedBox());
    expect((await result, controller.hasClients), (false, false));
  });
  testWidgets('when previous is requested after advancing, it should return to the prior item', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(controller: controller, children: SnapListTestHost.cards(3)),
      ),
    );
    await tester.pumpAndSettle();
    final advance = controller.next();
    await tester.pumpAndSettle();
    await advance;
    final result = controller.previous();
    await tester.pumpAndSettle();
    expect((await result, controller.position), (true, 0));
  });
  testWidgets('when jumping across eager items, it should settle at the target without animation', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(
          controller: controller,
          duration: const Duration(seconds: 10),
          children: SnapListTestHost.cards(20),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(17);
    expect((controller.index, controller.position, controller.isMoving), (17, 17, false));
  });
  testWidgets('when jumping across lazy items, it should only build near the destination', (tester) async {
    final controller = SnapListController();
    final built = <int>[];
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList.builder(
          controller: controller,
          itemCount: 1000,
          itemBuilder: (_, index) {
            built.add(index);
            return Text('Item $index');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(700);
    await tester.pump();
    expect(
      (controller.index, controller.position, built.every((index) => index < 4 || (index >= 698 && index <= 702))),
      (700, 700, true),
    );
  });
  testWidgets('when the jump index is outside the item range, it should reject it', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(SnapList(controller: controller, children: SnapListTestHost.cards(2))),
    );
    await tester.pumpAndSettle();
    expect(() => controller.jumpTo(2), throwsAssertionError);
  });
  testWidgets('when jumping to the selected item, it should not report an item change', (tester) async {
    final controller = SnapListController();
    final changes = <int>[];
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(
          controller: controller,
          onIndexChanged: changes.add,
          children: SnapListTestHost.cards(3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller
      ..jumpTo(2)
      ..jumpTo(2);
    expect(changes, [2]);
  });
  testWidgets('when jumping during navigation, it should interrupt the pending result', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(
          controller: controller,
          duration: const Duration(seconds: 1),
          children: SnapListTestHost.cards(5),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pending = controller.next();
    await tester.pump(const Duration(milliseconds: 100));
    controller.jumpTo(4);
    await tester.pumpAndSettle();
    expect((await pending, controller.index, controller.position, controller.isMoving), (false, 4, 4, false));
  });
  testWidgets('when jumping during a drag, it should stay at the requested item after release', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(SnapList(controller: controller, children: SnapListTestHost.cards(5))),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SnapList)));
    await gesture.moveBy(const Offset(0, -120));
    controller.jumpTo(4);
    await gesture.up();
    await tester.pumpAndSettle();
    expect((controller.index, controller.position, controller.isMoving), (4, 4, false));
  });
  testWidgets('when jumping from trailing content, it should show the requested real item', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(
          controller: controller,
          children: SnapListTestHost.cards(2),
          trailingBuilder: (_) => const SizedBox(height: 100),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final next = controller.next();
    await tester.pumpAndSettle();
    await next;
    final trailing = controller.next();
    await tester.pumpAndSettle();
    await trailing;
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect((controller.index, controller.position, controller.isMoving), (0, 0, false));
  });
  testWidgets('when the forward keyboard key is pressed, it should move one item', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(SnapList(controller: controller, children: SnapListTestHost.cards(3))),
    );
    await tester.pumpAndSettle();
    final focus = tester.widget<Focus>(find.descendant(of: find.byType(SnapList), matching: find.byType(Focus)).first);
    focus.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect((focus.onKeyEvent != null, controller.index), (true, 1));
  });
}
