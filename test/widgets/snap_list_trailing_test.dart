import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'snap_list_test.dart' show SnapListTestHost;

void main() {
  testWidgets('when an empty list receives its first items, it should replace trailing content with item zero', (
    tester,
  ) async {
    final controller = SnapListController();
    var count = 0;
    late StateSetter update;
    await tester.pumpWidget(
      SnapListTestHost.app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return SnapList.builder(
              spacing: 20,
              controller: controller,
              itemCount: count,
              itemBuilder: (_, index) => Text('Item $index'),
              trailingBuilder: (_) => const SizedBox.expand(child: Text('Empty')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final emptyRect = tester.getRect(find.text('Empty'));
    final viewport = tester.getRect(find.byType(SnapList));
    update(() => count = 3);
    await tester.pumpAndSettle();
    expect((emptyRect, controller.index, controller.position), (viewport, 0, 0));
  });

  testWidgets('when a lazy list appends after a committed trailing swipe, it should advance once', (tester) async {
    final controller = SnapListController();
    var count = 1;
    late StateSetter update;
    await tester.pumpWidget(
      SnapListTestHost.app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return SnapList.builder(
              controller: controller,
              itemCount: count,
              itemBuilder: (_, index) => Text('Item $index'),
              trailingBuilder: (_) => const SizedBox(height: 120),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SnapList), const Offset(0, -100));
    await tester.pumpAndSettle();
    final revealed = controller.position;
    update(() => count = 4);
    await tester.pumpAndSettle();
    expect((revealed, controller.index), (.3, 1));
  });

  testWidgets('when items append during a cancelled return, it should finish returning to the original item', (
    tester,
  ) async {
    final controller = SnapListController();
    var count = 1;
    late StateSetter update;
    await tester.pumpWidget(
      SnapListTestHost.app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return SnapList(
              controller: controller,
              trailingBuilder: (_) => const SizedBox(height: 120),
              children: SnapListTestHost.cards(count),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final reveal = controller.next();
    await tester.pumpAndSettle();
    await reveal;
    final back = controller.previous();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    update(() => count = 4);
    await tester.pumpAndSettle();
    await back;
    expect(controller.position, 0);
  });

  testWidgets(
    'when a full trailing slot disappears as an item appends, it should preserve the transition offset',
    (tester) async {
      final controller = SnapListController();
      var count = 1;
      late StateSetter update;
      await tester.pumpWidget(
        SnapListTestHost.app(
          StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return SnapList(
                controller: controller,
                trailingBuilder: count == 1 ? (_) => const SizedBox.expand() : null,
                children: SnapListTestHost.cards(count),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final reveal = controller.next();
      await tester.pumpAndSettle();
      await reveal;
      final before = controller.position;
      update(() => count = 2);
      await tester.pump();
      final afterLayout = controller.position;
      await tester.pumpAndSettle();
      expect((before, afterLayout, controller.position), (1, 1, 1));
    },
  );

  for (final axis in Axis.values) {
    testWidgets('when trailing content on $axis has a natural size, it should reveal that measured extent', (
      tester,
    ) async {
      final controller = SnapListController();
      await tester.pumpWidget(
        SnapListTestHost.app(
          SnapList(
            axis: axis,
            controller: controller,
            trailingBuilder: (_) =>
                SizedBox(width: axis == Axis.horizontal ? 90 : null, height: axis == Axis.vertical ? 120 : null),
            children: SnapListTestHost.cards(1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final result = controller.next();
      await tester.pumpAndSettle();
      expect((await result, controller.position, controller.index), (false, .3, 0));
    });
    testWidgets('when trailing content on $axis fills the viewport, it should fully replace the last item', (
      tester,
    ) async {
      final controller = SnapListController();
      await tester.pumpWidget(
        SnapListTestHost.app(
          SnapList(
            axis: axis,
            controller: controller,
            trailingBuilder: (_) => const SizedBox.expand(child: Text('End')),
            children: SnapListTestHost.cards(1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final result = controller.next();
      await tester.pumpAndSettle();
      await result;
      expect(tester.getRect(find.text('End')), tester.getRect(find.byType(SnapList)));
    });
  }

  for (final duringMotion in [false, true]) {
    testWidgets('when items append with trailing committed and moving=$duringMotion, it should advance once', (
      tester,
    ) async {
      final controller = SnapListController();
      var count = 1;
      late StateSetter update;
      await tester.pumpWidget(
        SnapListTestHost.app(
          StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return SnapList(
                controller: controller,
                trailingBuilder: (_) => const SizedBox(height: 120, child: Text('More')),
                children: SnapListTestHost.cards(count),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final result = controller.next();
      if (duringMotion) {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      } else {
        await tester.pumpAndSettle();
      }
      update(() => count = 4);
      await tester.pumpAndSettle();
      await result;
      expect((controller.index, controller.position), (1, 1));
    });
  }

  testWidgets('when the user returns before items append, it should keep the last original item', (tester) async {
    final controller = SnapListController();
    var count = 1;
    late StateSetter update;
    await tester.pumpWidget(
      SnapListTestHost.app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return SnapList(
              controller: controller,
              trailingBuilder: (_) => const SizedBox(height: 120),
              children: SnapListTestHost.cards(count),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final forward = controller.next();
    await tester.pumpAndSettle();
    await forward;
    final back = controller.previous();
    await tester.pumpAndSettle();
    await back;
    update(() => count = 3);
    await tester.pumpAndSettle();
    expect((controller.index, controller.position), (0, 0));
  });

  testWidgets('when a trailing drag is cancelled before items append, it should stay on its item', (tester) async {
    final controller = SnapListController();
    var count = 1;
    late StateSetter update;
    await tester.pumpWidget(
      SnapListTestHost.app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return SnapList(
              controller: controller,
              trailingBuilder: (_) => const SizedBox(height: 120),
              children: SnapListTestHost.cards(count),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SnapList)));
    await gesture.moveBy(const Offset(0, -80));
    await gesture.cancel();
    await tester.pumpAndSettle();
    update(() => count = 3);
    await tester.pumpAndSettle();
    expect(controller.position, 0);
  });

  testWidgets('when visible trailing content changes size or disappears, it should settle at the new boundary', (
    tester,
  ) async {
    final controller = SnapListController();
    var height = 120.0;
    late StateSetter update;
    await tester.pumpWidget(
      SnapListTestHost.app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return SnapList(
              controller: controller,
              trailingBuilder: height == 0 ? null : (_) => SizedBox(height: height),
              children: SnapListTestHost.cards(1),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final result = controller.next();
    await tester.pumpAndSettle();
    await result;
    update(() => height = 200);
    await tester.pumpAndSettle();
    final enlarged = controller.position;
    update(() => height = 60);
    await tester.pumpAndSettle();
    final shrunk = controller.position;
    update(() => height = 0);
    await tester.pumpAndSettle();
    expect((enlarged, shrunk, controller.position), (.5, .15, 0));
  });

  testWidgets('when motion is reduced, it should still show trailing content and then the appended item', (
    tester,
  ) async {
    final controller = SnapListController();
    var count = 1;
    late StateSetter update;
    await tester.pumpWidget(
      SnapListTestHost.app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return SnapList(
              controller: controller,
              trailingBuilder: (_) => const SizedBox.expand(child: Text('End')),
              children: SnapListTestHost.cards(count),
            );
          },
        ),
        reducedMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    final result = controller.next();
    await tester.pumpAndSettle();
    await result;
    final trailingRect = tester.getRect(find.text('End'));
    final viewport = tester.getRect(find.byType(SnapList));
    update(() => count = 3);
    await tester.pumpAndSettle();
    expect((trailingRect, controller.index), (viewport, 1));
  });

  testWidgets('when ticker mode disables during a trailing reveal, it should finish at the trailing boundary', (
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
            trailingBuilder: (_) => const SizedBox(height: 120),
            children: SnapListTestHost.cards(1),
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
    expect((controller.position, controller.index, controller.isMoving, completed), (.3, 0, false, false));
  });
}
