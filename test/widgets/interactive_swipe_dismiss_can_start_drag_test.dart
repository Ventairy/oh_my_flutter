import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  for (final handle in [false, true]) {
    for (final freeDrag in [false, true]) {
      for (final reducedMotion in [false, true]) {
        testWidgets(
          'when dragging is denied with handle $handle, free drag $freeDrag and reduced motion $reducedMotion, it should stay silent and still',
          (tester) async {
            var checks = 0;
            final callbacks = <String>[];
            await tester.pumpWidget(
              _GuardTestApp(
                handle: handle,
                freeDrag: freeDrag,
                reducedMotion: reducedMotion,
                canStartDrag: () {
                  checks++;
                  return false;
                },
                callbacks: callbacks,
              ),
            );
            final initial = tester.getTopLeft(find.byKey(_GuardTestApp.contentKey));
            final gesture = await tester.startGesture(tester.getCenter(find.byKey(_GuardTestApp.contentKey)));
            await gesture.moveBy(const Offset(40, 100));
            await tester.pump();
            final during = tester.getTopLeft(find.byKey(_GuardTestApp.contentKey));
            await gesture.moveBy(const Offset(-80, -200));
            await gesture.up();
            await tester.pumpAndSettle();
            expect(
              (checks, callbacks.isEmpty, during, tester.getTopLeft(find.byKey(_GuardTestApp.contentKey))),
              (1, true, initial, initial),
            );
          },
        );
      }
    }

    for (final permission in <bool?>[null, true]) {
      testWidgets('when the guard is $permission with handle $handle, it should preserve dismissal', (tester) async {
        final callbacks = <String>[];
        await tester.pumpWidget(
          _GuardTestApp(
            handle: handle,
            canStartDrag: permission == null ? null : () => permission,
            callbacks: callbacks,
          ),
        );
        await tester.drag(find.byKey(_GuardTestApp.contentKey), const Offset(0, 150));
        await tester.pumpAndSettle();
        expect(callbacks.where((value) => value == 'dismiss'), hasLength(1));
      });
    }

    for (final cancel in [false, true]) {
      testWidgets(
        'when permission changes after a denied touch with handle $handle and cancel $cancel, it should check the next touch',
        (tester) async {
          var allowed = false;
          var checks = 0;
          final callbacks = <String>[];
          await tester.pumpWidget(
            _GuardTestApp(
              handle: handle,
              canStartDrag: () {
                checks++;
                return allowed;
              },
              callbacks: callbacks,
            ),
          );
          final center = tester.getCenter(find.byKey(_GuardTestApp.contentKey));
          final first = await tester.startGesture(center, pointer: 10);
          allowed = true;
          await first.moveBy(const Offset(0, 150));
          if (cancel) {
            await first.cancel();
          } else {
            await first.up();
          }
          final firstCallbacks = List<String>.of(callbacks);
          final second = await tester.startGesture(center, pointer: 10);
          await second.moveBy(const Offset(0, 150));
          await second.up();
          await tester.pumpAndSettle();
          expect((checks, firstCallbacks.isEmpty, callbacks.where((value) => value == 'dismiss').length), (2, true, 1));
        },
      );
    }

    testWidgets(
      'when permission changes during an accepted touch with handle $handle, it should retain the initial decision',
      (tester) async {
        var allowed = true;
        var checks = 0;
        final callbacks = <String>[];
        await tester.pumpWidget(
          _GuardTestApp(
            handle: handle,
            canStartDrag: () {
              checks++;
              return allowed;
            },
            callbacks: callbacks,
          ),
        );
        final gesture = await tester.startGesture(tester.getCenter(find.byKey(_GuardTestApp.contentKey)));
        allowed = false;
        await gesture.moveBy(const Offset(0, 150));
        await gesture.up();
        await tester.pumpAndSettle();
        expect((checks, callbacks.where((value) => value == 'dismiss').length), (1, 1));
      },
    );

    testWidgets('when the guard throws with handle $handle, it should report once and recover for the next touch', (
      tester,
    ) async {
      var throws = true;
      final callbacks = <String>[];
      await tester.pumpWidget(
        _GuardTestApp(
          handle: handle,
          canStartDrag: () {
            if (throws) throw StateError('guard failed');
            return true;
          },
          callbacks: callbacks,
        ),
      );
      final center = tester.getCenter(find.byKey(_GuardTestApp.contentKey));
      final first = await tester.startGesture(center, pointer: 10);
      final error = tester.takeException();
      await first.moveBy(const Offset(0, 150));
      await first.cancel();
      final deniedCallbacks = List<String>.of(callbacks);
      throws = false;
      final second = await tester.startGesture(center, pointer: 10);
      await second.moveBy(const Offset(0, 150));
      await second.up();
      await tester.pumpAndSettle();
      expect(
        (
          error is StateError,
          tester.takeException(),
          deniedCallbacks.isEmpty,
          callbacks.where((value) => value == 'dismiss').length,
        ),
        (true, null, true, 1),
      );
    });

    testWidgets('when dragging is denied with handle $handle, it should preserve descendant taps and drags', (
      tester,
    ) async {
      var taps = 0;
      var updates = 0;
      await tester.pumpWidget(
        _GuardTestApp(
          handle: handle,
          canStartDrag: () => false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            onVerticalDragUpdate: (_) => updates++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.tap(find.byKey(_GuardTestApp.contentKey));
      await tester.drag(find.byKey(_GuardTestApp.contentKey), const Offset(0, 100));
      expect((taps, updates > 0), (1, true));
    });

    testWidgets('when dragging is denied with handle $handle, it should preserve descendant scrolling', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _GuardTestApp(
          handle: handle,
          canStartDrag: () => false,
          child: ListView.builder(
            controller: controller,
            itemExtent: 60,
            itemCount: 30,
            itemBuilder: (_, index) => Text('$index'),
          ),
        ),
      );
      await tester.drag(find.byKey(_GuardTestApp.contentKey), const Offset(0, -150));
      expect(controller.offset, greaterThan(0));
    });

    testWidgets('when a nested guard denies with handle $handle, it should allow the ancestor to dismiss', (
      tester,
    ) async {
      var outerDismissals = 0;
      var innerChecks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: InteractiveSwipeDismiss(
                dragConfig: const InteractiveSwipeDismissDragConfig(dismissFraction: 0.1),
                onDismiss: () {
                  outerDismissals++;
                  return false;
                },
                child: InteractiveSwipeDismiss(
                  canStartDrag: () {
                    innerChecks++;
                    return false;
                  },
                  onDismiss: () => throw StateError('inner should not dismiss'),
                  child: handle
                      ? const InteractiveSwipeDismissHandle(
                          child: ColoredBox(key: _GuardTestApp.contentKey, color: Colors.blue),
                        )
                      : const ColoredBox(key: _GuardTestApp.contentKey, color: Colors.blue),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.byKey(_GuardTestApp.contentKey), const Offset(0, 150));
      await tester.pumpAndSettle();
      expect((innerChecks, outerDismissals), (1, 1));
    });
  }
}

class _GuardTestApp extends StatelessWidget {
  const new({
    this.canStartDrag,
    this.handle = false,
    this.freeDrag = false,
    this.reducedMotion = false,
    this.callbacks,
    this.child,
  });

  static const ValueKey<String> contentKey = ValueKey('guard-content');
  final bool Function()? canStartDrag;
  final bool handle;
  final bool freeDrag;
  final bool reducedMotion;
  final List<String>? callbacks;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = ColoredBox(key: contentKey, color: Colors.blue, child: child ?? const SizedBox.expand());
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: InteractiveSwipeDismiss(
              canStartDrag: canStartDrag,
              dragConfig: InteractiveSwipeDismissDragConfig(freeDrag: freeDrag, dismissFraction: 0.1),
              onDismiss: () {
                callbacks?.add('dismiss');
                return false;
              },
              onOverdrag: (_) => callbacks?.add('overdrag'),
              onPositionChanged: (_, _) => callbacks?.add('position'),
              child: handle ? InteractiveSwipeDismissHandle(child: content) : content,
            ),
          ),
        ),
      ),
    );
  }
}
