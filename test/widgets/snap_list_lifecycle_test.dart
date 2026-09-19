import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'snap_list_test.dart' show SnapListTestHost;

class _Counter extends StatefulWidget {
  const new({required this.index, super.key});
  final int index;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> with AutomaticKeepAliveClientMixin {
  int taps = 0;
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => taps++),
      child: Text('${widget.index}:$taps'),
    );
  }
}

void main() {
  testWidgets('when lazy children request keep-alive, it should preserve state outside the cache window', (
    tester,
  ) async {
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList.builder(
          controller: controller,
          cacheItemCount: 0,
          incomingTransitionBuilder: (_, progress, isReverse, child) => FadeTransition(opacity: progress, child: child),
          outgoingTransitionBuilder: (_, progress, isReverse, child) =>
              ScaleTransition(scale: Tween<double>(begin: 1, end: .9).animate(progress), child: child),
          itemCount: 5,
          itemBuilder: (_, i) => _Counter(key: ValueKey(i), index: i),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('0:0'));
    for (var i = 0; i < 3; i++) {
      final result = controller.next();
      await tester.pumpAndSettle();
      await result;
    }
    for (var i = 0; i < 3; i++) {
      final result = controller.previous();
      await tester.pumpAndSettle();
      await result;
    }
    expect(find.text('0:1'), findsOneWidget);
  });
  testWidgets('when eager keyed items reorder, it should retain the selected item and state', (tester) async {
    final controller = SnapListController();
    var order = [0, 1, 2];
    late StateSetter update;
    await tester.pumpWidget(
      SnapListTestHost.app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return SnapList(
              controller: controller,
              incomingTransitionBuilder: (_, progress, isReverse, child) =>
                  FadeTransition(opacity: progress, child: child),
              outgoingTransitionBuilder: (_, progress, isReverse, child) =>
                  ScaleTransition(scale: Tween<double>(begin: 1, end: .9).animate(progress), child: child),
              children: [for (final i in order) _Counter(key: ValueKey(i), index: i)],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('0:0'));
    update(() => order = [1, 2, 0]);
    await tester.pumpAndSettle();
    expect((controller.index, find.text('0:1').evaluate().length), (2, 1));
  });
  testWidgets('when a lazy list animates within its prepared range, it should not rebuild item content each frame', (
    tester,
  ) async {
    final controller = SnapListController();
    var builds = 0;
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList.builder(
          controller: controller,
          itemCount: 1000,
          itemBuilder: (_, i) {
            builds++;
            return Text('$i');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initial = builds;
    final result = controller.next();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(builds - initial, lessThanOrEqualTo(1));
    await tester.pumpAndSettle();
    await result;
  });
  testWidgets('when lazy items are appended, it should retain the selected item and its state', (tester) async {
    final controller = SnapListController();
    var order = [0, 1, 2];
    late StateSetter update;
    await tester.pumpWidget(
      SnapListTestHost.app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return SnapList.builder(
              controller: controller,
              itemCount: order.length,
              itemBuilder: (_, i) => _Counter(key: ValueKey(order[i]), index: order[i]),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('0:0'));
    update(() => order = [0, 1, 2, 3]);
    await tester.pumpAndSettle();
    expect((controller.index, find.text('0:1').evaluate().length), (0, 1));
  });
  testWidgets('when the selected item is removed, it should select the nearest remaining index', (tester) async {
    final controller = SnapListController();
    var count = 3;
    late StateSetter update;
    await tester.pumpWidget(
      SnapListTestHost.app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return SnapList(controller: controller, children: SnapListTestHost.cards(count));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      final result = controller.next();
      await tester.pumpAndSettle();
      await result;
    }
    update(() => count = 1);
    await tester.pumpAndSettle();
    expect((controller.position, controller.index), (0, 0));
  });
  testWidgets('when the axis changes during movement, it should cancel the old command and retain the selected item', (
    tester,
  ) async {
    final controller = SnapListController();
    var axis = Axis.vertical;
    late StateSetter update;
    await tester.pumpWidget(
      SnapListTestHost.app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return SnapList(axis: axis, controller: controller, children: SnapListTestHost.cards(3));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final result = controller.next();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    update(() => axis = Axis.horizontal);
    await tester.pump();
    await tester.pumpAndSettle();
    expect((await result, controller.position), (false, 0));
  });

  testWidgets('when ticker mode disables during movement, it should finish at the selected item', (tester) async {
    final controller = SnapListController();
    final tickerEnabled = ValueNotifier<bool>(true);
    addTearDown(tickerEnabled.dispose);
    await tester.pumpWidget(
      SnapListTestHost.app(
        ValueListenableBuilder<bool>(
          valueListenable: tickerEnabled,
          builder: (_, enabled, child) => TickerMode(enabled: enabled, child: child!),
          child: SnapList(
            controller: controller,
            duration: const Duration(milliseconds: 400),
            children: SnapListTestHost.cards(3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    bool? completed;
    unawaited(controller.next().then((value) => completed = value));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tickerEnabled.value = false;
    await tester.pump();
    await tester.pump();
    expect((controller.position, controller.index, controller.isMoving, completed), (1, 1, false, true));
  });

  testWidgets('when ticker mode disables during backward movement, it should finish at the previous item', (
    tester,
  ) async {
    final controller = SnapListController();
    final tickerEnabled = ValueNotifier<bool>(true);
    addTearDown(tickerEnabled.dispose);
    await tester.pumpWidget(
      SnapListTestHost.app(
        ValueListenableBuilder<bool>(
          valueListenable: tickerEnabled,
          builder: (_, enabled, child) => TickerMode(enabled: enabled, child: child!),
          child: SnapList(
            controller: controller,
            duration: const Duration(milliseconds: 400),
            children: SnapListTestHost.cards(3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final next = controller.next();
    await tester.pumpAndSettle();
    expect(await next, isTrue);
    bool? completed;
    unawaited(controller.previous().then((value) => completed = value));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tickerEnabled.value = false;
    await tester.pump();
    await tester.pump();
    expect((controller.position, controller.index, controller.isMoving, completed), (0, 0, false, true));
  });
}
