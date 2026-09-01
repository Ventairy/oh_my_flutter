import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OffsetLayer, TransformLayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('InteractiveSwipeDismiss', () {
    testWidgets('when config is omitted, it should follow a downward pointer', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _TestApp(onDismiss: _TestApp.rejectDismissal),
      );
      final initial = _topLeft(tester);
      final gesture = await tester.startGesture(_center(tester));

      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();

      expect(_topLeft(tester) - initial, const Offset(0, 120));
    });

    testWidgets('when free drag is disabled, it should ignore cross movement', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _TestApp(onDismiss: _TestApp.rejectDismissal),
      );
      final initial = _topLeft(tester);
      final gesture = await tester.startGesture(_center(tester));

      await gesture.moveBy(const Offset(80, 120));
      await tester.pump();

      expect(_topLeft(tester) - initial, const Offset(0, 120));
    });

    testWidgets('when free drag is disabled, it should ignore opposite movement', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _TestApp(onDismiss: _TestApp.rejectDismissal),
      );
      final initial = _topLeft(tester);
      final gesture = await tester.startGesture(_center(tester));

      await gesture.moveBy(const Offset(0, -120));
      await tester.pump();

      expect(_topLeft(tester), initial);
    });

    testWidgets('when free drag is enabled, it should follow both axes', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _TestApp(
          dragConfig: InteractiveSwipeDismissDragConfig(
            freeDrag: true,
            sensitivity: 0.5,
          ),
          onDismiss: _TestApp.rejectDismissal,
        ),
      );
      final initial = _topLeft(tester);
      final gesture = await tester.startGesture(_center(tester));

      await gesture.moveBy(const Offset(80, 120));
      await tester.pump();

      expect(_topLeft(tester) - initial, const Offset(40, 60));
    });

    testWidgets(
      'when an unchanged child is translated, it should retain its paint',
      (tester) async {
        final painter = _PaintProbePainter();
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: CustomPaint(
              key: _TestApp.childKey,
              painter: painter,
            ),
          ),
        );
        final initialPaintCount = painter.paintCount;
        final gesture = await tester.startGesture(_center(tester));

        await gesture.moveBy(const Offset(0, 120));
        await tester.pump();

        expect(painter.paintCount, initialPaintCount);
      },
    );

    testWidgets(
      'when translated inside a nonzero inset, it should retain one offset layer and its child paint',
      (tester) async {
        final painter = _PaintProbePainter();
        await tester.pumpWidget(
          MaterialApp(
            home: Padding(
              padding: const EdgeInsets.all(12),
              child: InteractiveSwipeDismiss(
                onDismiss: _TestApp.rejectDismissal,
                child: CustomPaint(
                  key: _TestApp.childKey,
                  painter: painter,
                ),
              ),
            ),
          ),
        );
        final childRenderObject = tester.renderObject(
          find.byKey(_TestApp.childKey),
        );
        final translationRenderObject = childRenderObject.parent!;
        final initialLayer = translationRenderObject.debugLayer;
        final initialPaintCount = painter.paintCount;
        final gesture = await tester.startGesture(_center(tester));

        for (var index = 0; index < 20; index += 1) {
          await gesture.moveBy(const Offset(0, 4));
          await tester.pump();
        }
        final finalLayer = translationRenderObject.debugLayer;
        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(
          (
            identical(initialLayer, finalLayer),
            finalLayer is OffsetLayer && finalLayer is! TransformLayer,
            painter.paintCount,
          ),
          (true, true, initialPaintCount),
        );
      },
    );

    testWidgets(
      'when the child is translated, it should not rebuild the dismiss wrapper',
      (tester) async {
        final previousRebuildCallback = debugOnRebuildDirtyWidget;
        addTearDown(() {
          debugOnRebuildDirtyWidget = previousRebuildCallback;
        });
        await tester.pumpWidget(
          const _TestApp(onDismiss: _TestApp.rejectDismissal),
        );
        final dismissElement = tester.element(
          find.byType(InteractiveSwipeDismiss),
        );
        var rebuildCount = 0;
        debugOnRebuildDirtyWidget = (element, builtOnce) {
          previousRebuildCallback?.call(element, builtOnce);
          if (identical(element, dismissElement)) rebuildCount += 1;
        };
        final gesture = await tester.startGesture(_center(tester));

        await gesture.moveBy(const Offset(0, 120));
        await tester.pump();

        expect(rebuildCount, 0);
      },
    );

    testWidgets(
      'when cancellation restores an unchanged child, it should neither rebuild nor repaint',
      (tester) async {
        final painter = _PaintProbePainter();
        final previousRebuildCallback = debugOnRebuildDirtyWidget;
        addTearDown(() {
          debugOnRebuildDirtyWidget = previousRebuildCallback;
        });
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: CustomPaint(
              key: _TestApp.childKey,
              painter: painter,
            ),
          ),
        );
        final initialPaintCount = painter.paintCount;
        final dismissElement = tester.element(
          find.byType(InteractiveSwipeDismiss),
        );
        var rebuildCount = 0;
        debugOnRebuildDirtyWidget = (element, builtOnce) {
          previousRebuildCallback?.call(element, builtOnce);
          if (identical(element, dismissElement)) rebuildCount += 1;
        };
        final gesture = await tester.startGesture(_center(tester));

        await gesture.moveBy(const Offset(0, 120));
        await tester.pump();
        await gesture.cancel();
        await tester.pumpAndSettle();

        expect((rebuildCount, painter.paintCount), (0, initialPaintCount));
      },
    );

    testWidgets(
      'when a child animation repaints while translated, it should remain live',
      (tester) async {
        final animation = AnimationController(
          vsync: const TestVSync(),
          duration: const Duration(milliseconds: 100),
        )..repeat();
        addTearDown(animation.dispose);
        final painter = _PaintProbePainter(repaint: animation);
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: CustomPaint(
              key: _TestApp.childKey,
              painter: painter,
            ),
          ),
        );
        final gesture = await tester.startGesture(_center(tester));
        await gesture.moveBy(const Offset(0, 120));
        await tester.pump();
        final translatedPosition = _topLeft(tester);
        final paintCountBeforeTick = painter.paintCount;

        await tester.pump(const Duration(milliseconds: 40));
        final positionAfterTick = _topLeft(tester);
        final repaintContinued = painter.paintCount > paintCountBeforeTick;
        animation.stop();
        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(
          (positionAfterTick, repaintContinued),
          (translatedPosition, true),
        );
      },
    );

    testWidgets(
      'when a tappable descendant is translated, it should hit-test only at its translated location',
      (tester) async {
        const controlKey = ValueKey('translated-control');
        var taps = 0;
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: ColoredBox(
              key: _TestApp.childKey,
              color: Colors.white,
              child: Stack(
                children: [
                  Positioned(
                    left: 100,
                    top: 40,
                    child: GestureDetector(
                      key: controlKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps += 1,
                      child: const SizedBox(width: 100, height: 80),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final originalControlCenter = tester.getCenter(find.byKey(controlKey));
        final gesture = await tester.startGesture(const Offset(400, 400));

        await gesture.moveBy(const Offset(0, 120));
        await tester.pump();
        await tester.tapAt(originalControlCenter);
        await tester.tapAt(originalControlCenter + const Offset(0, 120));
        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(taps, 1);
      },
    );

    testWidgets(
      'when translation and restoration run, the semantics rect should follow both',
      (tester) async {
        const semanticsKey = ValueKey('translated-semantics');
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: ColoredBox(
              key: _TestApp.childKey,
              color: Colors.white,
              child: Stack(
                children: [
                  Positioned(
                    left: 100,
                    top: 40,
                    child: Semantics(
                      key: semanticsKey,
                      container: true,
                      button: true,
                      label: 'Translated control',
                      child: const SizedBox(width: 100, height: 80),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final semanticsFinder = find.byKey(semanticsKey);
        final initialRect = _semanticsRect(tester, semanticsFinder);
        final gesture = await tester.startGesture(const Offset(400, 400));

        await gesture.moveBy(const Offset(0, 120));
        await tester.pump();
        final translatedRect = _semanticsRect(tester, semanticsFinder);
        await gesture.cancel();
        await tester.pumpAndSettle();
        final restoredRect = _semanticsRect(tester, semanticsFinder);
        semantics.dispose();

        expect(
          (
            translatedRect.top - initialRect.top,
            translatedRect.left - initialRect.left,
            restoredRect,
          ),
          (120.0, 0.0, initialRect),
        );
      },
    );

    testWidgets(
      'when an annotated region is translated within an inset, it should be found at its visual position',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Padding(
              padding: EdgeInsets.all(12),
              child: InteractiveSwipeDismiss(
                onDismiss: _TestApp.rejectDismissal,
                child: AnnotatedRegion<String>(
                  value: 'translated-region',
                  child: ColoredBox(
                    key: _TestApp.childKey,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
        final childRenderObject = tester.renderObject(
          find.byKey(_TestApp.childKey),
        );
        var translationRenderObject = childRenderObject;
        while (!translationRenderObject.isRepaintBoundary) {
          translationRenderObject = translationRenderObject.parent!;
        }
        final translationLayer = translationRenderObject.debugLayer!;
        final gesture = await tester.startGesture(_center(tester));

        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();
        final atOriginalPosition = translationLayer.find<String>(
          const Offset(20, 20),
        );
        final atVisualPosition = translationLayer.find<String>(
          const Offset(20, 80),
        );
        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(
          (atOriginalPosition, atVisualPosition),
          (null, 'translated-region'),
        );
      },
    );

    testWidgets(
      'when sensitivity is reduced, it should preserve the raw threshold',
      (tester) async {
        var dismissals = 0;
        await tester.pumpWidget(
          _TestApp(
            dragConfig: const InteractiveSwipeDismissDragConfig(
              sensitivity: 0.2,
            ),
            onDismiss: () {
              dismissals += 1;
              return true;
            },
          ),
        );
        final initial = _topLeft(tester);
        final gesture = await tester.startGesture(_center(tester));

        await gesture.moveBy(const Offset(0, 360));
        await tester.pump(const Duration(milliseconds: 500));
        expect(_topLeft(tester) - initial, const Offset(0, 72));

        await gesture.up();
        await tester.pump();
        expect(dismissals, 1);
      },
    );

    testWidgets('when below threshold, it should not request dismissal', (
      tester,
    ) async {
      var dismissals = 0;
      await tester.pumpWidget(
        _TestApp(
          dragConfig: const InteractiveSwipeDismissDragConfig(
            dismissThreshold: 0.75,
          ),
          onDismiss: () {
            dismissals += 1;
            return true;
          },
        ),
      );
      final gesture = await tester.startGesture(_center(tester));

      await gesture.moveBy(const Offset(0, 200));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(dismissals, 0);
    });

    testWidgets('when velocity is sufficient, it should request dismissal', (
      tester,
    ) async {
      var dismissed = false;
      await tester.pumpWidget(
        _TestApp(
          dragConfig: const InteractiveSwipeDismissDragConfig(
            dismissThreshold: 0.95,
          ),
          onDismiss: () {
            dismissed = true;
            return true;
          },
        ),
      );

      await tester.fling(
        find.byKey(_TestApp.childKey),
        const Offset(0, 100),
        900,
      );
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('when dismissal is rejected, it should restore the child', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _TestApp(onDismiss: _TestApp.rejectDismissal),
      );
      final initial = _topLeft(tester);

      await tester.drag(find.byKey(_TestApp.childKey), const Offset(0, 360));
      await tester.pumpAndSettle();

      expect(_topLeft(tester), initial);
    });

    testWidgets('when accepted asynchronously, it should retain translation', (
      tester,
    ) async {
      final result = Completer<bool>();
      await tester.pumpWidget(_TestApp(onDismiss: () => result.future));
      final gesture = await tester.startGesture(_center(tester));

      await gesture.moveBy(const Offset(0, 360));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pump();
      final pendingPosition = _topLeft(tester);

      result.complete(true);
      await tester.pump();

      expect(_topLeft(tester), pendingPosition);
    });

    testWidgets('when pointer is cancelled, it should restore without dismiss', (
      tester,
    ) async {
      var dismissals = 0;
      await tester.pumpWidget(
        _TestApp(
          onDismiss: () {
            dismissals += 1;
            return true;
          },
        ),
      );
      final initial = _topLeft(tester);
      final gesture = await tester.startGesture(_center(tester));

      await gesture.moveBy(const Offset(0, 180));
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(_topLeft(tester), initial);
      expect(dismissals, 0);
    });

    testWidgets('when motion is reduced, it should dismiss without translation', (
      tester,
    ) async {
      var dismissals = 0;
      await tester.pumpWidget(
        _TestApp(
          disableAnimations: true,
          onDismiss: () {
            dismissals += 1;
            return true;
          },
        ),
      );
      final initial = _topLeft(tester);
      final gesture = await tester.startGesture(_center(tester));

      await gesture.moveBy(const Offset(0, 360));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_topLeft(tester), initial);

      await gesture.up();
      await tester.pump();
      expect(dismissals, 1);
    });

    for (final entry in <(InteractiveSwipeDismissDirection, Offset)>[
      (InteractiveSwipeDismissDirection.up, const Offset(0, -360)),
      (InteractiveSwipeDismissDirection.left, const Offset(-480, 0)),
      (InteractiveSwipeDismissDirection.right, const Offset(480, 0)),
    ]) {
      testWidgets(
        'when direction is ${entry.$1.name}, it should commit toward that edge',
        (tester) async {
          var dismissed = false;
          await tester.pumpWidget(
            _TestApp(
              direction: entry.$1,
              onDismiss: () {
                dismissed = true;
                return true;
              },
            ),
          );

          await tester.drag(find.byKey(_TestApp.childKey), entry.$2);
          await tester.pump();

          expect(dismissed, isTrue);
        },
      );
    }

    testWidgets('when scrolled away from edge, it should keep surface still', (
      tester,
    ) async {
      final controller = ScrollController(initialScrollOffset: 200);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _TestApp(
          onDismiss: _TestApp.rejectDismissal,
          child: ListView.builder(
            key: _TestApp.childKey,
            controller: controller,
            itemExtent: 100,
            itemCount: 20,
            itemBuilder: (_, index) => Text('$index'),
          ),
        ),
      );
      final initial = _topLeft(tester);

      await tester.drag(find.byKey(_TestApp.childKey), const Offset(0, 180));
      await tester.pump();

      expect(_topLeft(tester), initial);
    });

    testWidgets(
      'when an outer scroll is away from edge and its nested scroll is at edge, '
      'it should keep surface still',
      (tester) async {
        final outerController = ScrollController(initialScrollOffset: 100);
        final innerController = ScrollController();
        addTearDown(outerController.dispose);
        addTearDown(innerController.dispose);
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: SingleChildScrollView(
              key: _TestApp.childKey,
              controller: outerController,
              child: Column(
                children: [
                  const SizedBox(height: 250),
                  SizedBox(
                    height: 300,
                    child: ListView.builder(
                      key: const ValueKey('nested-inner-scrollable'),
                      controller: innerController,
                      itemExtent: 100,
                      itemCount: 20,
                      itemBuilder: (_, index) => Text('$index'),
                    ),
                  ),
                  const SizedBox(height: 450),
                ],
              ),
            ),
          ),
        );
        final initial = _topLeft(tester);

        await tester.drag(
          find.byKey(const ValueKey('nested-inner-scrollable')),
          const Offset(0, 60),
        );
        await tester.pump();

        expect(_topLeft(tester), initial);
      },
    );

    testWidgets(
      'when a reversed scrollable is at the physical dismissal edge, it should move the surface',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: ListView.builder(
              key: _TestApp.childKey,
              controller: controller,
              reverse: true,
              itemExtent: 100,
              itemCount: 20,
              itemBuilder: (_, index) => Text('$index'),
            ),
          ),
        );
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
        final initial = _topLeft(tester);
        final gesture = await tester.startGesture(_center(tester));

        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();
        final displacement = _topLeft(tester) - initial;
        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(displacement, const Offset(0, 60));
      },
    );

    testWidgets(
      'when a right-to-left scrollable is at the physical dismissal edge, it should move the surface',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _TestApp(
            direction: InteractiveSwipeDismissDirection.right,
            onDismiss: _TestApp.rejectDismissal,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ListView.builder(
                key: _TestApp.childKey,
                controller: controller,
                scrollDirection: Axis.horizontal,
                itemExtent: 100,
                itemCount: 20,
                itemBuilder: (_, index) => Text('$index'),
              ),
            ),
          ),
        );
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
        final initial = _topLeft(tester);
        final gesture = await tester.startGesture(_center(tester));

        await gesture.moveBy(const Offset(60, 0));
        await tester.pump();
        final displacement = _topLeft(tester) - initial;
        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(displacement, const Offset(60, 0));
      },
    );

    testWidgets(
      'when the configured axis changes, it should discard stale scroll arbitration',
      (tester) async {
        final controller = ScrollController(initialScrollOffset: 200);
        addTearDown(controller.dispose);
        var direction = InteractiveSwipeDismissDirection.down;
        late StateSetter updateDirection;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                updateDirection = setState;
                return InteractiveSwipeDismiss(
                  direction: direction,
                  onDismiss: _TestApp.rejectDismissal,
                  child: ListView.builder(
                    key: _TestApp.childKey,
                    controller: controller,
                    itemExtent: 100,
                    itemCount: 20,
                    itemBuilder: (_, index) => Text('$index'),
                  ),
                );
              },
            ),
          ),
        );
        updateDirection(() {
          direction = InteractiveSwipeDismissDirection.right;
        });
        await tester.pump();
        final initial = _topLeft(tester);
        final gesture = await tester.startGesture(_center(tester));

        await gesture.moveBy(const Offset(80, 0));
        await tester.pump();
        final displacement = _topLeft(tester) - initial;
        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(displacement, const Offset(80, 0));
      },
    );

    testWidgets(
      'when direction and drag config change during a handle gesture, it should finish with their pointer-down values',
      (tester) async {
        var direction = InteractiveSwipeDismissDirection.down;
        var dragConfig = const InteractiveSwipeDismissDragConfig(
          sensitivity: 0.5,
        );
        late StateSetter updateConfiguration;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                updateConfiguration = setState;
                return InteractiveSwipeDismiss(
                  direction: direction,
                  dragConfig: dragConfig,
                  onDismiss: _TestApp.rejectDismissal,
                  child: const InteractiveSwipeDismissHandle(
                    child: ColoredBox(
                      key: _TestApp.childKey,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        final initial = _topLeft(tester);
        final gesture = await tester.startGesture(_center(tester));

        updateConfiguration(() {
          direction = InteractiveSwipeDismissDirection.right;
          dragConfig = const InteractiveSwipeDismissDragConfig(
            sensitivity: 2,
          );
        });
        await tester.pump();
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump();
        final displacement = _topLeft(tester) - initial;
        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(displacement, const Offset(0, 50));
      },
    );

    testWidgets(
      'when a surface scroll reaches its dismissal edge, it should begin translation at the handoff move',
      (tester) async {
        final controller = ScrollController(initialScrollOffset: 64);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: ListView.builder(
              key: _TestApp.childKey,
              controller: controller,
              dragStartBehavior: DragStartBehavior.down,
              itemExtent: 100,
              itemCount: 20,
              itemBuilder: (_, index) => Text('$index'),
            ),
          ),
        );
        final initial = _topLeft(tester);
        final pointer = TestPointer(1, PointerDeviceKind.touch);
        final start = _center(tester);
        tester.binding.handlePointerEvent(pointer.down(start));
        double? firstDisplacement;

        for (var step = 1; step <= 30; step += 1) {
          tester.binding.handlePointerEvent(
            pointer.move(
              start + Offset(0, step * 8),
              timeStamp: Duration(milliseconds: step * 16),
            ),
          );
          await tester.pump();
          final displacement = (_topLeft(tester) - initial).dy;
          if (displacement > 0) {
            firstDisplacement = displacement;
            break;
          }
        }
        tester.binding.handlePointerEvent(
          pointer.cancel(timeStamp: const Duration(milliseconds: 512)),
        );
        await tester.pumpAndSettle();

        expect(firstDisplacement, 8);
      },
    );

    testWidgets(
      'when a surface scroll reaches its edge then reverses, it should scroll away instead of starting dismissal',
      (tester) async {
        final controller = ScrollController(initialScrollOffset: 64);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: ListView.builder(
              key: _TestApp.childKey,
              controller: controller,
              dragStartBehavior: DragStartBehavior.down,
              itemExtent: 100,
              itemCount: 20,
              itemBuilder: (_, index) => Text('$index'),
            ),
          ),
        );
        final pointer = TestPointer(1, PointerDeviceKind.touch);
        final start = _center(tester);
        tester.binding.handlePointerEvent(pointer.down(start));
        var step = 0;
        while (controller.offset > 0 && step < 30) {
          step += 1;
          tester.binding.handlePointerEvent(
            pointer.move(
              start + Offset(0, step * 8),
              timeStamp: Duration(milliseconds: step * 16),
            ),
          );
          await tester.pump();
        }

        tester.binding.handlePointerEvent(
          pointer.move(
            start + Offset(0, (step - 1) * 8),
            timeStamp: Duration(milliseconds: (step + 1) * 16),
          ),
        );
        await tester.pump();
        final offsetAfterReversal = controller.offset;
        tester.binding.handlePointerEvent(
          pointer.cancel(
            timeStamp: Duration(milliseconds: (step + 2) * 16),
          ),
        );
        await tester.pumpAndSettle();

        expect(offsetAfterReversal, greaterThan(0));
      },
    );

    testWidgets(
      'when a surface dismissal begins, it should freeze the active scroll offset',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: ListView.builder(
              key: _TestApp.childKey,
              controller: controller,
              itemExtent: 100,
              itemCount: 20,
              itemBuilder: (_, index) => Text('$index'),
            ),
          ),
        );
        final gesture = await tester.startGesture(_center(tester));
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();

        controller.jumpTo(100);
        await tester.pump();
        final offsetDuringDismissal = controller.offset;
        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(offsetDuringDismissal, 0);
      },
    );

    testWidgets('when handle is dragged while scrolled, it should dismiss', (
      tester,
    ) async {
      var dismissed = false;
      final controller = ScrollController(initialScrollOffset: 200);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _TestApp(
          onDismiss: () {
            dismissed = true;
            return true;
          },
          child: Column(
            key: _TestApp.childKey,
            children: [
              const InteractiveSwipeDismissHandle(
                key: ValueKey('handle'),
                child: SizedBox(width: double.infinity, height: 48),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemExtent: 100,
                  itemCount: 20,
                  itemBuilder: (_, index) => Text('$index'),
                ),
              ),
            ],
          ),
        ),
      );

      final handle = find.byKey(const ValueKey('handle'));
      final gesture = await tester.startGesture(
        tester.getTopLeft(handle) + const Offset(8, 8),
      );
      await gesture.moveBy(const Offset(0, 360));
      await gesture.up();
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets(
      'when a handle contains a scrolled view, it should freeze its offset while dragging',
      (tester) async {
        final controller = _TrackingScrollController(
          initialScrollOffset: 200,
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: InteractiveSwipeDismissHandle(
              child: ListView.builder(
                controller: controller,
                itemExtent: 100,
                itemCount: 20,
                itemBuilder: (_, index) => Text('$index'),
              ),
            ),
          ),
        );
        final correctionsBeforeDrag = controller.trackingPosition.correctPixelsCount;

        final gesture = await tester.startGesture(const Offset(200, 200));
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();

        expect(
          (
            controller.offset,
            controller.trackingPosition.correctPixelsCount,
          ),
          (200, correctionsBeforeDrag),
        );
        await gesture.up();
      },
    );

    testWidgets(
      'when a handle contains nested scrolls, '
      'it should freeze every active offset',
      (tester) async {
        final outerController = ScrollController(initialScrollOffset: 100);
        final innerController = ScrollController(initialScrollOffset: 200);
        addTearDown(outerController.dispose);
        addTearDown(innerController.dispose);
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: InteractiveSwipeDismissHandle(
              child: SingleChildScrollView(
                key: _TestApp.childKey,
                controller: outerController,
                child: Column(
                  children: [
                    const SizedBox(height: 250),
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        key: const ValueKey('nested-handle-scrollable'),
                        controller: innerController,
                        itemExtent: 100,
                        itemCount: 20,
                        itemBuilder: (_, index) => Text('$index'),
                      ),
                    ),
                    const SizedBox(height: 450),
                  ],
                ),
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(
            find.byKey(const ValueKey('nested-handle-scrollable')),
          ),
        );
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();

        outerController.jumpTo(150);
        innerController.jumpTo(250);
        await tester.pump();
        final frozenOffsets = (
          outerController.offset,
          innerController.offset,
        );
        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(frozenOffsets, (100, 200));
      },
    );

    testWidgets(
      'when handle moves are dispatched individually while scrolled, it should freeze every offset',
      (tester) async {
        final controller = ScrollController(initialScrollOffset: 200);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: InteractiveSwipeDismissHandle(
              child: ListView.builder(
                controller: controller,
                itemExtent: 100,
                itemCount: 20,
                itemBuilder: (_, index) => Text('$index'),
              ),
            ),
          ),
        );
        final pointer = TestPointer();
        const start = Offset(200, 200);
        await tester.sendEventToBinding(pointer.down(start));

        final offsets = <double>[];
        for (final entry in <(Offset, Duration)>[
          (const Offset(0, 20), const Duration(milliseconds: 16)),
          (const Offset(0, 50), const Duration(milliseconds: 32)),
          (const Offset(0, 90), const Duration(milliseconds: 48)),
        ]) {
          await tester.sendEventToBinding(
            pointer.move(start + entry.$1, timeStamp: entry.$2),
          );
          offsets.add(controller.offset);
        }
        await tester.sendEventToBinding(
          pointer.cancel(timeStamp: const Duration(milliseconds: 64)),
        );
        await tester.pumpAndSettle();

        expect(offsets, [200, 200, 200]);
      },
    );

    testWidgets(
      'when releasing a scroll hold emits synchronously, it should not acquire another hold',
      (tester) async {
        final controller = _ReentrantHoldScrollController(
          initialScrollOffset: 200,
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: InteractiveSwipeDismissHandle(
              child: ListView.builder(
                controller: controller,
                itemExtent: 100,
                itemCount: 20,
                itemBuilder: (_, index) => Text('$index'),
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(const Offset(200, 200));

        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();
        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(controller.trackingPosition.reentrantHoldCount, 0);
      },
    );

    testWidgets(
      'when a sibling scrollable changes during a drag, it should remain independent',
      (tester) async {
        final upperController = ScrollController();
        final lowerController = ScrollController(initialScrollOffset: 200);
        addTearDown(upperController.dispose);
        addTearDown(lowerController.dispose);
        await tester.pumpWidget(
          _TestApp(
            onDismiss: _TestApp.rejectDismissal,
            child: Column(
              key: _TestApp.childKey,
              children: [
                Expanded(
                  child: ListView.builder(
                    key: const ValueKey('upper-scrollable'),
                    controller: upperController,
                    itemExtent: 100,
                    itemCount: 20,
                    itemBuilder: (_, index) => Text('upper $index'),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: lowerController,
                    itemExtent: 100,
                    itemCount: 20,
                    itemBuilder: (_, index) => Text('lower $index'),
                  ),
                ),
              ],
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('upper-scrollable'))),
        );
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();

        lowerController.jumpTo(250);
        await tester.pump();
        lowerController.jumpTo(300);
        await tester.pump();
        final lowerOffset = lowerController.offset;
        await gesture.cancel();
        await tester.pumpAndSettle();

        expect(lowerOffset, 300);
      },
    );

    testWidgets(
      'when dismiss wrappers are nested, it should give the pointer to the nearest wrapper',
      (tester) async {
        const childKey = ValueKey('nested-dismiss-child');
        var outerDismissals = 0;
        var innerDismissals = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: InteractiveSwipeDismiss(
              dragConfig: const InteractiveSwipeDismissDragConfig(
                dismissThreshold: 0.1,
              ),
              onDismiss: () {
                outerDismissals += 1;
                return false;
              },
              child: InteractiveSwipeDismiss(
                dragConfig: const InteractiveSwipeDismissDragConfig(
                  dismissThreshold: 0.1,
                ),
                onDismiss: () {
                  innerDismissals += 1;
                  return false;
                },
                child: const ColoredBox(
                  key: childKey,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
        final initial = tester.getTopLeft(find.byKey(childKey));
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(childKey)),
        );

        await gesture.moveBy(const Offset(0, 100));
        await tester.pump();
        final displacement = tester.getTopLeft(find.byKey(childKey)) - initial;
        await gesture.up();
        await tester.pump();

        expect(
          (displacement, innerDismissals, outerDismissals),
          (const Offset(0, 100), 1, 0),
        );
      },
    );
  });
}

Offset _topLeft(WidgetTester tester) => tester.getTopLeft(find.byKey(_TestApp.childKey));

Offset _center(WidgetTester tester) => tester.getCenter(find.byKey(_TestApp.childKey));

Rect _semanticsRect(WidgetTester tester, Finder finder) {
  final node = tester.getSemantics(finder);
  final transform = node.transform;
  return transform == null ? node.rect : MatrixUtils.transformRect(transform, node.rect);
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.onDismiss,
    this.direction = InteractiveSwipeDismissDirection.down,
    this.dragConfig = const InteractiveSwipeDismissDragConfig(),
    this.disableAnimations = false,
    this.child = const ColoredBox(key: childKey, color: Colors.white),
  });

  static const ValueKey<String> childKey = ValueKey('interactive-child');

  static bool rejectDismissal() => false;

  final FutureOr<bool> Function() onDismiss;
  final InteractiveSwipeDismissDirection direction;
  final InteractiveSwipeDismissDragConfig dragConfig;
  final bool disableAnimations;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          disableAnimations: disableAnimations,
        ),
        child: InteractiveSwipeDismiss(
          direction: direction,
          dragConfig: dragConfig,
          onDismiss: onDismiss,
          child: child,
        ),
      ),
    );
  }
}

class _PaintProbePainter extends CustomPainter {
  _PaintProbePainter({super.repaint});

  int paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount += 1;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PaintProbePainter oldDelegate) => false;
}

class _TrackingScrollController extends ScrollController {
  _TrackingScrollController({required super.initialScrollOffset});

  late _TrackingScrollPosition trackingPosition;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return trackingPosition = _TrackingScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _TrackingScrollPosition extends ScrollPositionWithSingleContext {
  _TrackingScrollPosition({
    required super.physics,
    required super.context,
    required super.initialPixels,
    required super.keepScrollOffset,
    required super.oldPosition,
    required super.debugLabel,
  });

  int correctPixelsCount = 0;

  @override
  void correctPixels(double value) {
    correctPixelsCount += 1;
    super.correctPixels(value);
  }
}

class _ReentrantHoldScrollController extends ScrollController {
  _ReentrantHoldScrollController({required super.initialScrollOffset});

  late _ReentrantHoldScrollPosition trackingPosition;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return trackingPosition = _ReentrantHoldScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _ReentrantHoldScrollPosition extends ScrollPositionWithSingleContext {
  _ReentrantHoldScrollPosition({
    required super.physics,
    required super.context,
    required super.initialPixels,
    required super.keepScrollOffset,
    required super.oldPosition,
    required super.debugLabel,
  });

  int holdCount = 0;
  int reentrantHoldCount = 0;
  bool _isCancellingHold = false;

  @override
  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    holdCount += 1;
    if (_isCancellingHold) reentrantHoldCount += 1;
    final delegate = super.hold(holdCancelCallback);
    return _SynchronousNotificationScrollHoldController(() {
      _isCancellingHold = true;
      try {
        delegate.cancel();
        final notificationContext = context.notificationContext;
        if (notificationContext == null) return;
        ScrollStartNotification(
          metrics: this,
          context: notificationContext,
        ).dispatch(notificationContext);
      } finally {
        _isCancellingHold = false;
      }
    });
  }
}

class _SynchronousNotificationScrollHoldController implements ScrollHoldController {
  _SynchronousNotificationScrollHoldController(this._onCancel);

  final VoidCallback _onCancel;

  @override
  void cancel() => _onCancel();
}
