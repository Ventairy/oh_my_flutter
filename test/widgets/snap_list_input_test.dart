import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'snap_list_test.dart' show SnapListTestHost;

void main() {
  for (final axis in Axis.values) {
    for (final direction in [-1, 1]) {
      for (final speed in [350.0, 450.0]) {
        testWidgets(
          'when a short $axis swipe has speed $speed and direction $direction, it should apply the fling threshold',
          (tester) async {
            final controller = SnapListController();
            await tester.pumpWidget(
              SnapListTestHost.app(
                SnapList(
                  axis: axis,
                  controller: controller,
                  children: SnapListTestHost.cards(3),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final advance = controller.next();
            await tester.pumpAndSettle();
            await advance;
            final distance = -60.0 * direction;
            await tester.fling(
              find.byType(SnapList),
              axis == Axis.vertical ? Offset(0, distance) : Offset(distance, 0),
              speed,
            );
            await tester.pumpAndSettle();
            expect(controller.index, speed > 400 ? 1 + direction : 1);
          },
        );
      }
    }
  }

  testWidgets('when touch takes over a wheel burst, it should stay under the finger until release', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(SnapList(controller: controller, children: SnapListTestHost.cards(3))),
    );
    await tester.pumpAndSettle();
    final point = tester.getCenter(find.byType(SnapList));
    await tester.sendEventToBinding(PointerScrollEvent(position: point, scrollDelta: const Offset(0, 100)));
    final gesture = await tester.startGesture(point);
    await gesture.moveBy(const Offset(0, -30));
    await gesture.moveBy(const Offset(0, -30));
    final heldPosition = controller.position;
    await tester.pump(const Duration(milliseconds: 121));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.position, heldPosition);
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('when horizontal direction is RTL, it should advance toward the logical end', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(axis: Axis.horizontal, controller: controller, children: SnapListTestHost.cards(3)),
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SnapList), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(controller.index, 1);
  });
  testWidgets('when a trackpad pan ends, it should settle on the next item', (tester) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(SnapList(controller: controller, children: SnapListTestHost.cards(3))),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await gesture.panZoomStart(tester.getCenter(find.byType(SnapList)));
    await gesture.panZoomUpdate(tester.getCenter(find.byType(SnapList)), pan: const Offset(0, -30));
    await gesture.panZoomUpdate(tester.getCenter(find.byType(SnapList)), pan: const Offset(0, -230));
    await gesture.panZoomEnd();
    await tester.pumpAndSettle();
    expect(controller.index, 1);
  });
  testWidgets('when a nested trackpad pan reaches its edge, it should transfer to the list', (tester) async {
    final controller = SnapListController();
    final inner = ScrollController();
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(
          controller: controller,
          children: [
            SingleChildScrollView(
              controller: inner,
              child: const SizedBox(height: 1000, child: Text('Nested')),
            ),
            const Text('Next'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    inner.jumpTo(inner.position.maxScrollExtent);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    final point = tester.getCenter(find.byType(SnapList));
    await gesture.panZoomStart(point);
    await gesture.panZoomUpdate(point, pan: const Offset(0, -30));
    await gesture.panZoomUpdate(point, pan: const Offset(0, -240));
    await gesture.panZoomEnd();
    await tester.pumpAndSettle();
    expect(controller.index, 1);
  });
  testWidgets('when accessibility requests scrolling forward, it should update the selected index', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(SnapList(controller: controller, children: SnapListTestHost.cards(3))),
    );
    await tester.pumpAndSettle();
    final owner = tester.binding.renderViews.first.owner!.semanticsOwner!;
    SemanticsNode? target;
    void visit(SemanticsNode node) {
      if (node.getSemanticsData().hasAction(ui.SemanticsAction.scrollUp)) target = node;
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(owner.rootSemanticsNode!);
    owner.performAction(target!.id, ui.SemanticsAction.scrollUp);
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    semantics.dispose();
  });
}
