import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'snap_list_test.dart' show SnapListTestHost;

void main() {
  for (final axis in Axis.values) {
    testWidgets('when a nested $axis scrollable reaches its edge, it should transfer the same drag', (tester) async {
      final controller = SnapListController();
      final inner = ScrollController();
      await tester.pumpWidget(
        SnapListTestHost.app(
          SnapList(
            axis: axis,
            controller: controller,
            children: [
              SingleChildScrollView(
                controller: inner,
                scrollDirection: axis,
                child: SizedBox(
                  width: axis == Axis.horizontal ? 900 : null,
                  height: axis == Axis.vertical ? 1000 : 200,
                  child: const Text('Nested'),
                ),
              ),
              const Text('Next'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      inner.jumpTo(inner.position.maxScrollExtent - 20);
      await tester.pump();
      final gesture = await tester.startGesture(tester.getCenter(find.byType(SnapList)));
      await gesture.moveBy(axis == Axis.vertical ? const Offset(0, -50) : const Offset(-50, 0));
      await tester.pump();
      await gesture.moveBy(axis == Axis.vertical ? const Offset(0, -180) : const Offset(-160, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.index, 1);
    });
  }
  testWidgets('when nested content can still scroll, it should not change the selected item', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(
          controller: controller,
          children: const [
            SingleChildScrollView(child: SizedBox(height: 2000, child: Text('Nested'))),
            Text('Next'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(controller.position, 0);
  });
}
