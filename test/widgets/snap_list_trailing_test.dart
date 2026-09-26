import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'snap_list_test.dart' show SnapListTestHost;

class _SnapListTrailingTestCapture {
  static Future<int> redPixels(
    WidgetTester tester,
    GlobalKey captureKey,
    Axis axis, {
    bool includeFaded = false,
  }) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
    return (await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var count = 0;
      final extent = axis == Axis.vertical ? image.height : image.width;
      for (var position = 0; position < extent; position++) {
        final x = axis == Axis.vertical ? image.width ~/ 2 : position;
        final y = axis == Axis.vertical ? position : image.height ~/ 2;
        final offset = (y * image.width + x) * 4;
        if (bytes.getUint8(offset) == 255 &&
            bytes.getUint8(offset + 1) < 255 &&
            bytes.getUint8(offset + 2) < 255 &&
            (includeFaded || (bytes.getUint8(offset + 1) == 0 && bytes.getUint8(offset + 2) == 0))) {
          count++;
        }
      }
      image.dispose();
      return count;
    }))!;
  }
}

void main() {
  for (final lazy in [false, true]) {
    for (final (axis, direction, spacing) in [
      (Axis.vertical, TextDirection.ltr, 10.0),
      (Axis.horizontal, TextDirection.ltr, 32.0),
      (Axis.horizontal, TextDirection.rtl, 10.0),
    ]) {
      testWidgets(
        'when unclipped trailing content enters on $axis $direction lazy=$lazy, it should scroll in without a paint jump or added effect',
        (tester) async {
          await tester.binding.setSurfaceSize(axis == Axis.vertical ? const Size(200, 400) : const Size(400, 200));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final captureKey = GlobalKey();
          var builds = 0;
          final trailer = Builder(
            builder: (_) {
              builds++;
              return Padding(
                padding: axis == Axis.vertical
                    ? const EdgeInsets.only(top: 50, bottom: 20)
                    : const EdgeInsetsDirectional.only(start: 50, end: 20),
                child: SizedBox(
                  height: axis == Axis.vertical ? 16 : null,
                  width: axis == Axis.horizontal ? 16 : null,
                  child: const ColoredBox(color: Color(0xffff0000)),
                ),
              );
            },
          );
          await tester.pumpWidget(
            Directionality(
              textDirection: direction,
              child: RepaintBoundary(
                key: captureKey,
                child: ColoredBox(
                  color: const Color(0xffffffff),
                  child: Center(
                    child: SizedBox(
                      width: axis == Axis.vertical ? 200 : 300,
                      height: axis == Axis.vertical ? 300 : 200,
                      child: lazy
                          ? SnapList.builder(
                              axis: axis,
                              spacing: spacing,
                              clipBehavior: Clip.none,
                              itemCount: 1,
                              cacheItemCount: 0,
                              itemBuilder: (_, _) => const ColoredBox(color: Color(0xff00ff00)),
                              trailingBuilder: (_) => trailer,
                            )
                          : SnapList(
                              axis: axis,
                              spacing: spacing,
                              clipBehavior: Clip.none,
                              trailingBuilder: (_) => trailer,
                              children: const [ColoredBox(color: Color(0xff00ff00))],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
          final frames = <int>[];
          for (final pixels in [0.0, 1.0, 5.0, 10.0, 11.0, 16.0, 20.0, 86.0, 5.0, 0.0]) {
            position.jumpTo(pixels);
            await tester.pump();
            frames.add(await _SnapListTrailingTestCapture.redPixels(tester, captureKey, axis));
          }
          expect(
            [frames, builds],
            [
              [0, 1, 5, 10, 11, 16, 16, 16, 5, 0],
              1,
            ],
          );
        },
      );
    }
  }

  testWidgets('when earlier items remain, it should keep the trailer offscreen until scrolling beyond the last item', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(200, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: captureKey,
          child: ColoredBox(
            color: const Color(0xffffffff),
            child: Center(
              child: SizedBox(
                width: 200,
                height: 300,
                child: SnapList.builder(
                  clipBehavior: Clip.none,
                  spacing: 10,
                  itemCount: 3,
                  itemBuilder: (_, _) => const ColoredBox(color: Color(0xff00ff00)),
                  trailingBuilder: (_) => const Padding(
                    padding: EdgeInsets.only(top: 50, bottom: 20),
                    child: SizedBox(height: 16, child: ColoredBox(color: Color(0xffff0000))),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    final frames = <int>[];
    for (final pixels in [0.0, 20.0, 300.0, 310.0, 330.0, 610.0, 620.0, 621.0, 625.0, 640.0]) {
      position.jumpTo(pixels);
      await tester.pump();
      frames.add(await _SnapListTrailingTestCapture.redPixels(tester, captureKey, Axis.vertical));
    }
    expect(frames, [0, 0, 0, 0, 0, 0, 0, 1, 5, 16]);
  });

  testWidgets(
    'when an animated trailer sits behind a footer, it should not flash while swiping earlier items or returning to rest',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(200, 450));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final captureKey = GlobalKey();
      final animationController = AnimationController(vsync: tester, duration: const Duration(milliseconds: 300))
        ..repeat();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: captureKey,
            child: ColoredBox(
              color: const Color(0xffffffff),
              child: Center(
                child: SizedBox(
                  width: 200,
                  height: 300,
                  child: SnapList.builder(
                    clipBehavior: Clip.none,
                    spacing: 10,
                    cacheItemCount: 3,
                    itemCount: 4,
                    incomingTransitionBuilder: (_, progress, details, child) =>
                        FadeTransition(opacity: progress, child: child),
                    outgoingTransitionBuilder: (_, progress, details, child) =>
                        FadeTransition(opacity: Tween<double>(begin: 1, end: 0).animate(progress), child: child),
                    itemBuilder: (_, _) => const ColoredBox(color: Color(0xff00ff00)),
                    trailingBuilder: (_) => Padding(
                      padding: const EdgeInsets.only(top: 50, bottom: 20),
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: animationController,
                          builder: (_, child) =>
                              Transform.translate(offset: Offset(animationController.value, 0), child: child),
                          child: const SizedBox(height: 16, child: ColoredBox(color: Color(0xffff0000))),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      final frames = <int>[];
      for (final pixels in [0.0, 20.0, 50.0, 20.0, 0.0, 930.0, 950.0, 1016.0, 950.0, 930.0, 0.0]) {
        position.jumpTo(pixels);
        for (var frame = 0; frame < 3; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          frames.add(
            await _SnapListTrailingTestCapture.redPixels(tester, captureKey, Axis.vertical, includeFaded: true),
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      animationController.dispose();
      expect(frames, [
        for (final pixels in [0, 0, 0, 0, 0, 0, 16, 16, 16, 0, 0]) ...[pixels, pixels, pixels],
      ]);
    },
  );

  testWidgets(
    'when trailing content paints outside an unclipped viewport, it should keep offscreen semantics and taps excluded',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(200, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 200,
              height: 300,
              child: SnapList.builder(
                clipBehavior: Clip.none,
                spacing: 10,
                itemCount: 1,
                itemBuilder: (_, _) => const SizedBox.expand(),
                trailingBuilder: (_) => Padding(
                  padding: const EdgeInsets.only(top: 50, bottom: 20),
                  child: Semantics(
                    label: 'Trailing action',
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps++,
                      child: const SizedBox(height: 16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(find.byType(Scrollable)).position..jumpTo(20);
      await tester.pump();
      final outsideSemantics = find.semantics.byLabel('Trailing action').evaluate().isEmpty;
      await tester.tapAt(const Offset(100, 385));
      final outsideTaps = taps;
      position.jumpTo(86);
      await tester.pump();
      final insideSemantics = find.semantics.byLabel('Trailing action').evaluate().isNotEmpty;
      await tester.tapAt(const Offset(100, 320));
      semantics.dispose();
      expect((outsideSemantics, outsideTaps, insideSemantics, taps), (true, 0, true, 1));
    },
  );

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
              clipBehavior: Clip.none,
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
              clipBehavior: Clip.none,
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
