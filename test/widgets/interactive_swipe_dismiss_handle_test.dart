import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('InteractiveSwipeDismissHandle', () {
    testWidgets('when no ancestor exists, it should reject mounting', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: InteractiveSwipeDismissHandle(child: SizedBox()),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('when a custom child is provided, it should display that child', (
      tester,
    ) async {
      const customKey = ValueKey('custom-handle');
      await tester.pumpWidget(
        MaterialApp(
          home: InteractiveSwipeDismiss(
            onDismiss: () => false,
            child: const InteractiveSwipeDismissHandle(
              child: SizedBox(key: customKey, width: 48, height: 8),
            ),
          ),
        ),
      );

      expect(find.byKey(customKey), findsOneWidget);
    });

    testWidgets('when wrapping a child, it should preserve its size', (
      tester,
    ) async {
      const childKey = ValueKey('sized-child');
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: InteractiveSwipeDismiss(
              onDismiss: () => false,
              child: const InteractiveSwipeDismissHandle(
                child: SizedBox(key: childKey, width: 120, height: 56),
              ),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(childKey)), const Size(120, 56));
    });

    testWidgets(
      'when wrapping a scrollable, it should prevent observable scroll movement',
      (tester) async {
        final controller = ScrollController(initialScrollOffset: 200);
        addTearDown(controller.dispose);
        final observedOffsets = <double>[];
        controller.addListener(() => observedOffsets.add(controller.offset));
        await tester.pumpWidget(
          _HandleTestApp(
            child: InteractiveSwipeDismissHandle(
              child: ListView.builder(
                key: const ValueKey('scrollable-handle'),
                controller: controller,
                dragStartBehavior: DragStartBehavior.down,
                itemExtent: 100,
                itemCount: 20,
                itemBuilder: (_, index) => Text('$index'),
              ),
            ),
          ),
        );
        observedOffsets.clear();
        final pointer = TestPointer(1, PointerDeviceKind.touch);
        final center = tester.getCenter(
          find.byKey(const ValueKey('scrollable-handle')),
        );

        tester.binding.handlePointerEvent(pointer.down(center));
        tester.binding.handlePointerEvent(
          pointer.move(center + const Offset(0, 11)),
        );
        tester.binding.handlePointerEvent(
          pointer.move(center + const Offset(0, 23)),
        );
        tester.binding.handlePointerEvent(
          pointer.move(center + const Offset(0, 35)),
        );
        await tester.pump();
        tester.binding.handlePointerEvent(pointer.up());

        expect(observedOffsets, isEmpty);
      },
    );

    testWidgets(
      'when wrapping a matching drag recognizer, it should suppress descendant drag updates',
      (tester) async {
        var descendantUpdates = 0;
        await tester.pumpWidget(
          _HandleTestApp(
            child: InteractiveSwipeDismissHandle(
              child: GestureDetector(
                key: const ValueKey('vertical-drag-handle'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (_) => descendantUpdates += 1,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('vertical-drag-handle'))),
        );

        await gesture.moveBy(const Offset(0, 11));
        await gesture.moveBy(const Offset(0, 12));
        await gesture.up();

        expect(descendantUpdates, 0);
      },
    );

    testWidgets('when wrapping a tappable child, it should preserve taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _HandleTestApp(
          child: InteractiveSwipeDismissHandle(
            child: GestureDetector(
              key: const ValueKey('tappable-handle'),
              behavior: HitTestBehavior.opaque,
              onTap: () => taps += 1,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('tappable-handle')));

      expect(taps, 1);
    });

    testWidgets(
      'when wrapping a cross-axis drag recognizer, it should preserve that gesture',
      (tester) async {
        var descendantUpdates = 0;
        await tester.pumpWidget(
          _HandleTestApp(
            child: InteractiveSwipeDismissHandle(
              child: GestureDetector(
                key: const ValueKey('horizontal-drag-handle'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (_) => descendantUpdates += 1,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('horizontal-drag-handle'))),
        );

        await gesture.moveBy(const Offset(11, 0));
        await gesture.moveBy(const Offset(12, 0));
        await gesture.up();

        expect(descendantUpdates, greaterThan(0));
      },
    );

    testWidgets('when handles are nested, it should apply each pointer delta once', (
      tester,
    ) async {
      const childKey = ValueKey('nested-handle-child');
      await tester.pumpWidget(
        const _HandleTestApp(
          child: InteractiveSwipeDismissHandle(
            child: InteractiveSwipeDismissHandle(
              child: SizedBox.expand(key: childKey),
            ),
          ),
        ),
      );
      final initial = tester.getTopLeft(find.byKey(childKey));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(childKey)),
      );

      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      final displacement = tester.getTopLeft(find.byKey(childKey)) - initial;
      await gesture.up();
      await tester.pumpAndSettle();

      expect(displacement, const Offset(0, 20));
    });

    testWidgets(
      'when an active handle is reparented, it should preserve its pointer-down owner',
      (tester) async {
        const childKey = ValueKey('reparented-handle-child');
        final handleKey = GlobalKey();
        var useSecondOwner = false;
        var firstDismissals = 0;
        var secondDismissals = 0;
        late StateSetter updateOwner;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                updateOwner = setState;
                final handle = InteractiveSwipeDismissHandle(
                  key: handleKey,
                  child: const SizedBox.expand(
                    child: ColoredBox(
                      key: childKey,
                      color: Colors.white,
                    ),
                  ),
                );
                return Column(
                  children: [
                    Expanded(
                      child: InteractiveSwipeDismiss(
                        dragConfig: const InteractiveSwipeDismissDragConfig(
                          dismissThreshold: 0.1,
                        ),
                        onDismiss: () {
                          firstDismissals += 1;
                          return false;
                        },
                        child: useSecondOwner ? const SizedBox.expand() : handle,
                      ),
                    ),
                    Expanded(
                      child: InteractiveSwipeDismiss(
                        dragConfig: const InteractiveSwipeDismissDragConfig(
                          dismissThreshold: 0.1,
                        ),
                        onDismiss: () {
                          secondDismissals += 1;
                          return false;
                        },
                        child: useSecondOwner ? handle : const SizedBox.expand(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(childKey)),
        );
        final pointerDownHandle = tester.element(find.byKey(handleKey));

        updateOwner(() {
          useSecondOwner = true;
        });
        await tester.pump();
        final handleWasReparented = identical(
          pointerDownHandle,
          tester.element(find.byKey(handleKey)),
        );
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump();
        await gesture.up();
        await tester.pump();

        expect(
          (handleWasReparented, firstDismissals, secondDismissals),
          (true, 1, 0),
        );
      },
    );
  });
}

class _HandleTestApp extends StatelessWidget {
  const _HandleTestApp({required this.child});

  final Widget child;

  static bool _rejectDismissal() => false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: InteractiveSwipeDismiss(
        onDismiss: _rejectDismissal,
        child: child,
      ),
    );
  }
}
