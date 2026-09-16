import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'snap_list_test.dart' show SnapListTestHost;

void main() {
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
