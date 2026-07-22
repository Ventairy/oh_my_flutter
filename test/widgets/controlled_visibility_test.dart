import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

const _childKey = Key('controlled-child');

Widget _testApp({
  required Widget child,
  bool disableAnimations = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(body: Center(child: child)),
  ),
);

Widget _fadeTransition(Widget child, Animation<double> animation) => FadeTransition(opacity: animation, child: child);

FadeTransition _fade(WidgetTester tester) => tester.widget<FadeTransition>(
  find.descendant(
    of: find.byType(ControlledVisibility),
    matching: find.byType(FadeTransition),
  ),
);

Visibility _visibility(WidgetTester tester) => tester.widget<Visibility>(
  find.descendant(
    of: find.byType(ControlledVisibility),
    matching: find.byType(Visibility),
  ),
);

void main() {
  group('ControlledVisibility without a transition', () {
    testWidgets('when show is called, it should show immediately', (
      tester,
    ) async {
      final controller = ControlledVisibilityController();
      await tester.pumpWidget(
        _testApp(
          child: ControlledVisibility(
            controller: controller,
            child: const Text('Details'),
          ),
        ),
      );

      controller.show();
      await tester.pump();

      expect(_visibility(tester).visible, isTrue);
    });

    testWidgets('when hide is called, it should hide immediately', (
      tester,
    ) async {
      final controller = ControlledVisibilityController()..show();
      await tester.pumpWidget(
        _testApp(
          child: ControlledVisibility(
            controller: controller,
            child: const Text('Details'),
          ),
        ),
      );
      await tester.pump();

      controller.hide();
      await tester.pump();

      expect(_visibility(tester).visible, isFalse);
    });

    testWidgets(
      'when hidden and mounted, it should retain the child layout size',
      (tester) async {
        final controller = ControlledVisibilityController();
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              child: const SizedBox(
                key: _childKey,
                width: 80,
                height: 40,
              ),
            ),
          ),
        );

        final size = tester.getSize(
          find.byKey(_childKey, skipOffstage: false),
        );

        expect(size, const Size(80, 40));
      },
    );

    testWidgets(
      'when hidden and mounted, it should prevent pointer interaction',
      (tester) async {
        final controller = ControlledVisibilityController();
        var tapCount = 0;
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              child: GestureDetector(
                key: _childKey,
                onTap: () => tapCount += 1,
                child: const SizedBox(width: 80, height: 40),
              ),
            ),
          ),
        );

        await tester.tap(
          find.byKey(_childKey, skipOffstage: false),
          warnIfMissed: false,
        );

        expect(tapCount, 0);
      },
    );

    testWidgets(
      'when hidden and mounted, it should exclude the child semantics',
      (tester) async {
        final controller = ControlledVisibilityController();
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              child: Semantics(
                label: 'Hidden details',
                child: const SizedBox(width: 80, height: 40),
              ),
            ),
          ),
        );

        expect(_visibility(tester).maintainSemantics, isFalse);
      },
    );
  });

  group('ControlledVisibility transitions', () {
    testWidgets(
      'when show is called, it should drive the transition from 0 to 1',
      (tester) async {
        final controller = ControlledVisibilityController();
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              showDuration: const Duration(milliseconds: 200),
              showTransition: _fadeTransition,
              child: const Text('Details'),
            ),
          ),
        );

        controller.show();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final halfway = _fade(tester).opacity.value;
        await tester.pump(const Duration(milliseconds: 100));

        expect(halfway, closeTo(0.5, 0.01));
      },
    );

    testWidgets(
      'when hide is called, it should use the independent hide duration',
      (tester) async {
        final controller = ControlledVisibilityController()..show();
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              showDuration: const Duration(milliseconds: 200),
              hideDuration: const Duration(milliseconds: 100),
              showTransition: _fadeTransition,
              hideTransition: _fadeTransition,
              child: const Text('Details'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        controller.hide();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(_fade(tester).opacity.value, closeTo(0.5, 0.01));
      },
    );

    testWidgets(
      'when durations change, it should use the updated duration',
      (tester) async {
        final controller = ControlledVisibilityController();
        Widget build(Duration duration) => _testApp(
          child: ControlledVisibility(
            controller: controller,
            showDuration: duration,
            showTransition: _fadeTransition,
            child: const Text('Details'),
          ),
        );

        await tester.pumpWidget(build(const Duration(milliseconds: 300)));
        await tester.pumpWidget(build(const Duration(milliseconds: 100)));
        controller.show();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(_fade(tester).opacity.value, 1);
      },
    );

    testWidgets(
      'when reduced motion is requested, it should skip the transition',
      (tester) async {
        final controller = ControlledVisibilityController();
        await tester.pumpWidget(
          _testApp(
            disableAnimations: true,
            child: ControlledVisibility(
              controller: controller,
              showTransition: _fadeTransition,
              child: const Text('Details'),
            ),
          ),
        );

        controller.show();
        await tester.pump();

        expect(_visibility(tester).visible, isTrue);
        expect(
          find.descendant(
            of: find.byType(ControlledVisibility),
            matching: find.byType(FadeTransition),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'when the show transition is absent, it should show immediately',
      (tester) async {
        final controller = ControlledVisibilityController();
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              showDuration: const Duration(days: 1),
              hideTransition: _fadeTransition,
              child: const Text('Details'),
            ),
          ),
        );

        controller.show();
        await tester.pump();

        expect(_visibility(tester).visible, isTrue);
      },
    );

    testWidgets(
      'when the hide transition is absent, it should hide immediately',
      (tester) async {
        final controller = ControlledVisibilityController()..show();
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              showTransition: _fadeTransition,
              hideDuration: const Duration(days: 1),
              child: const Text('Details'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        controller.hide();
        await tester.pump();

        expect(_visibility(tester).visible, isFalse);
      },
    );

    testWidgets(
      'when transition wrappers differ, it should preserve the child state',
      (tester) async {
        final controller = ControlledVisibilityController()..show();
        var initCount = 0;
        var disposeCount = 0;
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              showDuration: const Duration(milliseconds: 100),
              hideDuration: const Duration(milliseconds: 100),
              showTransition: _fadeTransition,
              hideTransition: (child, animation) => ScaleTransition(
                scale: animation,
                child: Padding(padding: EdgeInsets.zero, child: child),
              ),
              child: _LifecycleChild(
                onInit: () => initCount += 1,
                onDispose: () => disposeCount += 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        controller.hide();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.descendant(
            of: find.byType(ControlledVisibility),
            matching: find.byType(ScaleTransition),
          ),
          findsOneWidget,
        );
        expect((initCount, disposeCount), (1, 0));
      },
    );
  });

  group('ControlledVisibility lifecycle', () {
    testWidgets(
      'when show is called before mounting, it should apply the command',
      (tester) async {
        final controller = ControlledVisibilityController()..show();

        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              showTransition: _fadeTransition,
              child: const Text('Details'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(_fade(tester).opacity.value, 1);
      },
    );

    testWidgets(
      'when hidden without unmounting, it should retain the child state',
      (tester) async {
        final controller = ControlledVisibilityController()..show();
        var disposeCount = 0;
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              child: _LifecycleChild(onDispose: () => disposeCount += 1),
            ),
          ),
        );

        controller.hide();
        await tester.pump();

        expect(disposeCount, 0);
      },
    );

    testWidgets(
      'when unmounting and showing again, it should create a fresh subtree',
      (tester) async {
        final controller = ControlledVisibilityController();
        var initCount = 0;
        var disposeCount = 0;
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              unmount: true,
              child: _LifecycleChild(
                onInit: () => initCount += 1,
                onDispose: () => disposeCount += 1,
              ),
            ),
          ),
        );

        controller.show();
        await tester.pump();
        controller.hide();
        await tester.pump();
        controller.show();
        await tester.pump();

        expect((initCount, disposeCount), (2, 1));
      },
    );

    testWidgets(
      'when the controller changes, the old controller should detach',
      (tester) async {
        final oldController = ControlledVisibilityController();
        final newController = ControlledVisibilityController();
        Widget build(ControlledVisibilityController controller) => _testApp(
          child: ControlledVisibility(
            controller: controller,
            showTransition: _fadeTransition,
            child: const Text('Details'),
          ),
        );

        await tester.pumpWidget(build(oldController));
        await tester.pumpWidget(build(newController));
        oldController.show();
        await tester.pump();

        expect(_visibility(tester).visible, isFalse);
      },
    );

    testWidgets(
      'when disposed, its former controller should remain safe to call',
      (tester) async {
        final controller = ControlledVisibilityController();
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              child: const Text('Details'),
            ),
          ),
        );
        await tester.pumpWidget(_testApp(child: const SizedBox.shrink()));

        expect(() {
          controller
            ..show()
            ..hide();
        }, returnsNormally);
      },
    );
  });

  group('ControlledVisibility callbacks', () {
    testWidgets(
      'when hide duration is zero, it should complete the hide operation immediately',
      (tester) async {
        final controller = ControlledVisibilityController()..show();
        var hideCalled = false;
        var hideCompleted = false;
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              hideDuration: Duration.zero,
              hideTransition: _fadeTransition,
              onHide: (future) {
                hideCalled = true;
                unawaited(future.then((_) => hideCompleted = true));
              },
              child: const Text('Details'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        controller.hide();
        await tester.pump();

        expect(
          (hideCalled, hideCompleted, _visibility(tester).visible),
          (true, true, false),
        );
      },
    );

    testWidgets(
      'when a transition completes, its operation future should complete',
      (tester) async {
        final controller = ControlledVisibilityController();
        Future<void>? operation;
        var completed = false;
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              showDuration: const Duration(milliseconds: 100),
              showTransition: _fadeTransition,
              onShow: (future) {
                operation = future;
                unawaited(future.then((_) => completed = true));
              },
              child: const Text('Details'),
            ),
          ),
        );

        controller.show();
        final calledImmediately = operation != null;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final completedHalfway = completed;
        await tester.pumpAndSettle();

        expect(
          (calledImmediately, completedHalfway, completed),
          (true, false, true),
        );
      },
    );

    testWidgets(
      'when an operation is interrupted, its future should complete',
      (tester) async {
        final controller = ControlledVisibilityController();
        var showCompleted = false;
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              showTransition: _fadeTransition,
              hideTransition: _fadeTransition,
              onShow: (future) => unawaited(future.then((_) => showCompleted = true)),
              child: const Text('Details'),
            ),
          ),
        );

        controller.show();
        await tester.pump();
        controller.hide();
        await tester.pump();

        expect(showCompleted, isTrue);
      },
    );

    testWidgets(
      'when no transition exists, its operation future should complete immediately',
      (tester) async {
        final controller = ControlledVisibilityController();
        Future<void>? operation;
        await tester.pumpWidget(
          _testApp(
            child: ControlledVisibility(
              controller: controller,
              onShow: (future) => operation = future,
              child: const Text('Details'),
            ),
          ),
        );

        controller.show();

        expect(operation, completes);
      },
    );
  });
}

class _LifecycleChild extends StatefulWidget {
  const _LifecycleChild({required this.onDispose, this.onInit});

  final VoidCallback? onInit;
  final VoidCallback onDispose;

  @override
  State<_LifecycleChild> createState() => _LifecycleChildState();
}

class _LifecycleChildState extends State<_LifecycleChild> {
  @override
  void initState() {
    super.initState();
    widget.onInit?.call();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 20);
}
