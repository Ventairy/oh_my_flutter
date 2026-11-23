import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  test('when the interval is zero, it should diagnose the invalid configuration', () {
    expect(() => SnapListTransientItem.every(0, builder: (_, _) => null), throwsAssertionError);
  });

  testWidgets('when the first opportunity is empty, it should still offer the final complete group', (tester) async {
    final pager = SnapListController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SnapList.builder(
          controller: pager,
          itemCount: 4,
          itemBuilder: (_, index) => Center(child: Text('Item $index')),
          transientItem: .every(2, builder: (_, index) => index == 3 ? const Center(child: Text('Extra')) : null),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final stops = <int?>[];
    for (var step = 0; step < 4; step++) {
      final reached = pager.next();
      await tester.pumpAndSettle();
      await reached;
      stops.add(pager.index);
    }
    expect((stops.join(','), find.text('Extra').hitTestable().evaluate().length), ('1,2,3,3', 1));
  });
  for (final eager in [false, true]) {
    testWidgets('when traversing a transient with eager=$eager, it should share both main coordinates', (tester) async {
      final fixture = _TransientFixture(eager: eager);
      await tester.pumpWidget(fixture.build());
      await tester.pumpAndSettle();
      fixture.controller.jumpTo(4);
      await tester.pumpAndSettle();
      final stops = <(int?, double?, bool)>[];
      for (final step in [1, 1, -1, -1]) {
        final reached = step > 0 ? fixture.controller.next() : fixture.controller.previous();
        await tester.pumpAndSettle();
        stops.add((fixture.controller.index, fixture.controller.position, await reached));
      }
      expect(stops, [(4, 4.0, true), (5, 5.0, true), (4, 4.0, true), (4, 4.0, true)]);
    });
  }

  testWidgets('when an earlier slot changes, it should keep the selected child at its screen offset', (tester) async {
    final fixture = _TransientFixture();
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    fixture.controller.jumpTo(5);
    await tester.pumpAndSettle();
    final item = find.text('Item 5');
    final offset = tester.getTopLeft(item);
    final offsets = <Offset>[];
    for (final available in [false, true]) {
      fixture.available = available;
      await tester.pumpWidget(fixture.build());
      offsets.add(tester.getTopLeft(item));
    }
    expect(offsets, [offset, offset]);
  });

  testWidgets('when dragging toward a transient, it should move the page with stationary logical position', (
    tester,
  ) async {
    final fixture = _TransientFixture();
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    fixture.controller.jumpTo(4);
    await tester.pumpAndSettle();
    final item = find.text('Item 4');
    final offset = tester.getTopLeft(item);
    final drag = await tester.startGesture(tester.getCenter(item));
    await drag.moveBy(const Offset(0, -30));
    await drag.moveBy(const Offset(0, -120));
    await tester.pump();
    expect((fixture.controller.position, tester.getTopLeft(item).dy < offset.dy), (4.0, true));
    await drag.up();
    await tester.pumpAndSettle();
  });

  testWidgets('when the visible transient is removed, it should show the successor', (tester) async {
    final fixture = _TransientFixture();
    await tester.pumpWidget(fixture.build());
    fixture.controller.jumpTo(4);
    await tester.pumpAndSettle();
    final reached = fixture.controller.next();
    await tester.pumpAndSettle();
    await reached;
    fixture.available = false;
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    expect(find.text('Item 5').hitTestable(), findsOneWidget);
  });

  testWidgets('when leaving a transient, it should track the drag toward the next main index', (tester) async {
    final fixture = _TransientFixture();
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    fixture.controller.jumpTo(4);
    await tester.pumpAndSettle();
    final reached = fixture.controller.next();
    await tester.pumpAndSettle();
    await reached;
    final transient = find.text('Extra 4');
    final initial = tester.getTopLeft(transient);
    final drag = await tester.startGesture(tester.getCenter(transient));
    await drag.moveBy(const Offset(0, -30));
    await drag.moveBy(const Offset(0, -120));
    await tester.pump();
    final fraction = (initial.dy - tester.getTopLeft(transient).dy) / tester.getSize(find.byType(SnapList)).height;
    expect(fixture.controller.position, closeTo(4 + fraction, 0.0001));
    await drag.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('when jumping to the main index from its transient, it should select the main item', (tester) async {
    final fixture = _TransientFixture();
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    fixture.controller.jumpTo(4);
    await tester.pumpAndSettle();
    final reached = fixture.controller.next();
    await tester.pumpAndSettle();
    await reached;
    fixture.controller.jumpTo(4);
    await tester.pumpAndSettle();
    expect(find.text('Item 4').hitTestable(), findsOneWidget);
  });

  testWidgets('when a final transient disappears, it should reveal trailing content', (tester) async {
    final fixture = _TransientFixture(count: 5, trailing: true);
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    fixture.controller.jumpTo(4);
    await tester.pumpAndSettle();
    final reached = fixture.controller.next();
    await tester.pumpAndSettle();
    await reached;
    fixture.available = false;
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    expect(find.text('Trailer').hitTestable(), findsOneWidget);
  });

  testWidgets('when a slot changes at the trailer, it should preserve the trailer until main items append', (
    tester,
  ) async {
    final fixture = _TransientFixture(count: 5, trailing: true)..available = false;
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    fixture.controller.jumpTo(4);
    await tester.pumpAndSettle();
    final trailing = fixture.controller.next();
    await tester.pumpAndSettle();
    await trailing;
    final trailer = find.text('Trailer');
    final initial = tester.getTopLeft(trailer);
    fixture.available = true;
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    final retained = tester.getTopLeft(trailer);
    fixture.count++;
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    expect((retained, fixture.controller.index), (initial, 5));
  });

  testWidgets('when availability changes mid-swipe, it should finish the original gesture before reconciling', (
    tester,
  ) async {
    final fixture = _TransientFixture();
    await tester.pumpWidget(fixture.build());
    await tester.pumpAndSettle();
    fixture.controller.jumpTo(4);
    await tester.pumpAndSettle();
    final drag = await tester.startGesture(tester.getCenter(find.text('Item 4')));
    await drag.moveBy(const Offset(0, -30));
    await drag.moveBy(const Offset(0, -320));
    await tester.pump();
    final transient = find.text('Extra 4');
    final beforeUpdate = tester.getTopLeft(transient);
    fixture.available = false;
    await tester.pumpWidget(fixture.build());
    final afterUpdate = tester.getTopLeft(transient);
    await drag.up();
    await tester.pumpAndSettle();
    expect((afterUpdate, fixture.controller.index), (beforeUpdate, 5));
  });

  testWidgets('when jumping far, it should resolve only nearby transient opportunities', (tester) async {
    final fixture = _TransientFixture();
    await tester.pumpWidget(fixture.build());
    fixture.controller.jumpTo(900);
    await tester.pumpAndSettle();
    expect(fixture.visited.where((index) => index > 10 && index < 890), isEmpty);
  });
}

class _TransientFixture {
  new({this.eager = false, this.count = 1000, this.trailing = false});

  int count;
  final bool trailing;

  final bool eager;
  final controller = SnapListController();
  final visited = <int>{};
  bool available = true;

  Widget build() {
    final rule = SnapListTransientItem.every(
      5,
      builder: (_, index) {
        visited.add(index);
        return available ? Center(child: Text('Extra $index')) : null;
      },
    );
    Widget item(int index) => Center(child: Text('Item $index'));
    return Directionality(
      textDirection: TextDirection.ltr,
      child: eager
          ? SnapList(controller: controller, transientItem: rule, children: List.generate(12, item))
          : SnapList.builder(
              controller: controller,
              transientItem: rule,
              itemCount: count,
              trailingBuilder: trailing ? (_) => const Center(heightFactor: 2, child: Text('Trailer')) : null,
              itemBuilder: (_, i) => item(i),
            ),
    );
  }
}
