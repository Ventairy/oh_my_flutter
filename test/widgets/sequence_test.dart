import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

const _firstKey = Key('first');
const _secondKey = Key('second');
const _thirdKey = Key('third');

Widget _testApp({
  required Widget child,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

List<Widget> _children() {
  return const [
    Text('First', key: _firstKey),
    Text('Second', key: _secondKey),
    Text('Third', key: _thirdKey),
  ];
}

Widget _fade(Widget child, Animation<double> animation) {
  return FadeTransition(opacity: animation, child: child);
}

FadeTransition _fadeFor(WidgetTester tester, Key key) {
  return tester.widget<FadeTransition>(
    find
        .ancestor(
          of: find.byKey(key, skipOffstage: false),
          matching: find.byType(FadeTransition),
        )
        .first,
  );
}

void main() {
  group('Sequence construction', () {
    test('when children are empty, it should reject construction', () {
      expect(
        () => Sequence(children: const []),
        throwsAssertionError,
      );
    });

    testWidgets('when mounted, it should initially show the first child', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(child: Sequence(children: _children())),
      );

      expect(
        (
          find.text('First').evaluate().length,
          find.text('Second').evaluate().length,
        ),
        (1, 0),
      );
    });

    testWidgets(
      'when no controller is supplied, it should create one internally',
      (tester) async {
        await tester.pumpWidget(
          _testApp(child: Sequence(children: _children())),
        );

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('SequenceController navigation', () {
    test('when unattached, next should throw a state error', () {
      final controller = SequenceController();

      expect(controller.next, throwsStateError);
    });

    test('when unattached, previous should throw a state error', () {
      final controller = SequenceController();

      expect(controller.previous, throwsStateError);
    });

    test('when unattached, goTo should throw a state error', () {
      final controller = SequenceController();

      expect(() => controller.goTo(1), throwsStateError);
    });

    testWidgets('when next is called, it should select the next child', (
      tester,
    ) async {
      final controller = SequenceController();
      await tester.pumpWidget(
        _testApp(
          child: Sequence(controller: controller, children: _children()),
        ),
      );

      controller.next();
      await tester.pump();

      expect((controller.index, find.text('Second').evaluate().length), (1, 1));
    });

    testWidgets(
      'when previous is called, it should select the previous child',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(controller: controller, children: _children()),
          ),
        );
        controller.goTo(2);
        await tester.pump();

        controller.previous();
        await tester.pump();

        expect((controller.index, find.text('Second').evaluate().length), (1, 1));
      },
    );

    testWidgets('when goTo is called, it should select that child', (
      tester,
    ) async {
      final controller = SequenceController();
      await tester.pumpWidget(
        _testApp(
          child: Sequence(controller: controller, children: _children()),
        ),
      );

      controller.goTo(2);
      await tester.pump();

      expect((controller.index, find.text('Third').evaluate().length), (2, 1));
    });

    testWidgets('when goTo is out of range, it should throw a range error', (
      tester,
    ) async {
      final controller = SequenceController();
      await tester.pumpWidget(
        _testApp(
          child: Sequence(controller: controller, children: _children()),
        ),
      );

      expect(() => controller.goTo(3), throwsRangeError);
    });

    testWidgets('when navigation stays at a boundary, it should be a no-op', (
      tester,
    ) async {
      final controller = SequenceController();
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      await tester.pumpWidget(
        _testApp(
          child: Sequence(controller: controller, children: _children()),
        ),
      );

      controller
        ..previous()
        ..goTo(0);
      await tester.pump();

      expect((controller.index, notifications), (0, 0));
    });

    testWidgets(
      'when next is called at the final child, it should be a no-op',
      (tester) async {
        final controller = SequenceController();
        var notifications = 0;
        controller.addListener(() => notifications += 1);
        await tester.pumpWidget(
          _testApp(
            child: Sequence(controller: controller, children: _children()),
          ),
        );
        controller.goTo(2);
        await tester.pump();
        notifications = 0;

        controller.next();

        expect((controller.index, notifications), (2, 0));
      },
    );

    testWidgets('when navigation changes index, it should notify listeners', (
      tester,
    ) async {
      final controller = SequenceController();
      var notifications = 0;
      controller.addListener(() => notifications += 1);
      await tester.pumpWidget(
        _testApp(
          child: Sequence(controller: controller, children: _children()),
        ),
      );

      controller.next();

      expect((controller.index, notifications), (1, 1));
    });

    testWidgets(
      'when its sequence is disposed, it should reject navigation',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(controller: controller, children: _children()),
          ),
        );

        await tester.pumpWidget(_testApp(child: const SizedBox.shrink()));

        expect(controller.next, throwsStateError);
      },
    );
  });

  group('Sequence transitions', () {
    testWidgets(
      'when children have unequal sizes, it should align them at the directional top start by default',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              nextTransition: _fade,
              children: const [
                SizedBox(key: _firstKey, width: 40, height: 20),
                SizedBox(key: _secondKey, width: 100, height: 50),
              ],
            ),
          ),
        );

        controller.next();
        await tester.pump();

        expect(
          tester.getTopLeft(find.byKey(_firstKey)),
          tester.getTopLeft(find.byKey(_secondKey)),
        );
      },
    );

    testWidgets(
      'when alignment is provided, it should align unequal transition participants accordingly',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              alignment: AlignmentDirectional.bottomEnd,
              nextTransition: _fade,
              children: const [
                SizedBox(key: _firstKey, width: 40, height: 20),
                SizedBox(key: _secondKey, width: 100, height: 50),
              ],
            ),
          ),
        );

        controller.next();
        await tester.pump();

        expect(
          tester.getBottomRight(find.byKey(_firstKey)),
          tester.getBottomRight(find.byKey(_secondKey)),
        );
      },
    );

    testWidgets(
      'when moving forward, it should transition both participating children',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              duration: const Duration(milliseconds: 200),
              reverseDuration: const Duration(milliseconds: 200),
              nextTransition: _fade,
              children: _children(),
            ),
          ),
        );

        controller.next();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          [
            _fadeFor(tester, _firstKey).opacity.value,
            _fadeFor(tester, _secondKey).opacity.value,
          ],
          everyElement(closeTo(0.5, 0.01)),
        );
      },
    );

    testWidgets(
      'when moving backward, it should use the previous transition',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              previousTransition: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              children: _children(),
            ),
          ),
        );
        controller.goTo(1);
        await tester.pump();

        controller.previous();
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(Sequence),
            matching: find.byType(ScaleTransition),
          ),
          findsNWidgets(2),
        );
      },
    );

    testWidgets(
      'when durations differ, it should animate each side independently',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              duration: const Duration(milliseconds: 100),
              reverseDuration: const Duration(milliseconds: 200),
              nextTransition: _fade,
              children: _children(),
            ),
          ),
        );

        controller.next();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final sourceValue = _fadeFor(tester, _firstKey).opacity.value;
        final targetValue = _fadeFor(tester, _secondKey).opacity.value;

        expect(
          sourceValue >= 0.49 && sourceValue <= 0.51 && targetValue == 1,
          isTrue,
        );
      },
    );

    testWidgets(
      'when each side has a different duration, it should clean up each side independently',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              duration: const Duration(milliseconds: 200),
              reverseDuration: const Duration(milliseconds: 50),
              nextTransition: _fade,
              children: _children(),
            ),
          ),
        );

        controller.next();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 75));

        expect(
          (
            find.byKey(_firstKey).evaluate().length,
            find.byKey(_secondKey).evaluate().length,
          ),
          (0, 1),
        );
      },
    );

    testWidgets(
      'when a transition is absent, it should switch immediately',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              duration: const Duration(days: 1),
              children: _children(),
            ),
          ),
        );

        controller.next();
        await tester.pump();

        expect(
          (
            find.text('First').evaluate().length,
            find.text('Second').evaluate().length,
          ),
          (0, 1),
        );
      },
    );

    testWidgets(
      'when reduced motion is requested, it should skip the transition',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            disableAnimations: true,
            child: Sequence(
              controller: controller,
              nextTransition: _fade,
              children: _children(),
            ),
          ),
        );

        controller.next();
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(Sequence),
            matching: find.byType(FadeTransition),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'when a command interrupts motion, it should select the latest target',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              duration: const Duration(milliseconds: 100),
              reverseDuration: const Duration(milliseconds: 100),
              nextTransition: _fade,
              children: _children(),
            ),
          ),
        );

        controller.next();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        controller.next();
        await tester.pump();
        await tester.pumpAndSettle();

        expect((controller.index, find.text('Third').evaluate().length), (2, 1));
      },
    );
  });

  group('Sequence performance structure', () {
    testWidgets(
      'when a large sequence transitions, it should mount only the current and outgoing children',
      (tester) async {
        final controller = SequenceController();
        var mounted = 0;
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              nextTransition: _fade,
              children: List.generate(
                1000,
                (index) => _LifecycleChild(
                  key: ValueKey(index),
                  onInit: () => mounted += 1,
                  onDispose: () {},
                ),
              ),
            ),
          ),
        );

        controller.next();
        await tester.pump();

        expect(mounted, 2);
      },
    );

    testWidgets(
      'when an animation advances, it should not reinvoke transition builders',
      (tester) async {
        final controller = SequenceController();
        var builds = 0;
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              duration: const Duration(milliseconds: 300),
              reverseDuration: const Duration(milliseconds: 300),
              nextTransition: (child, animation) {
                builds += 1;
                return FadeTransition(opacity: animation, child: child);
              },
              children: _children(),
            ),
          ),
        );

        controller.next();
        await tester.pump();
        final buildsAfterNavigation = builds;
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect((buildsAfterNavigation, builds), (2, 2));
      },
    );

    testWidgets(
      'when an animated sequence settles, it should remove transition wrappers',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              nextTransition: _fade,
              children: _children(),
            ),
          ),
        );

        controller.next();
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(Sequence),
            matching: find.byType(FadeTransition),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'when both animation durations are zero, it should not retain transition wrappers',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              duration: Duration.zero,
              reverseDuration: Duration.zero,
              nextTransition: _fade,
              children: _children(),
            ),
          ),
        );

        controller.next();
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(Sequence),
            matching: find.byType(FadeTransition),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'when the destination duration is zero, it should wrap only the outgoing child',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              duration: Duration.zero,
              nextTransition: _fade,
              children: _children(),
            ),
          ),
        );

        controller.next();
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(Sequence),
            matching: find.byType(FadeTransition),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'when the source duration is zero, it should wrap only the destination child',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              reverseDuration: Duration.zero,
              nextTransition: _fade,
              children: _children(),
            ),
          ),
        );

        controller.next();
        await tester.pump();

        expect(
          find.descendant(
            of: find.byType(Sequence),
            matching: find.byType(FadeTransition),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'when an animated sequence is settled, it should not schedule continuing frames',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              nextTransition: _fade,
              children: _children(),
            ),
          ),
        );
        controller.next();
        await tester.pumpAndSettle();

        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );
  });

  group('Sequence child lifecycle', () {
    testWidgets(
      'when keepMounted is false, it should dispose an exited child',
      (tester) async {
        final controller = SequenceController();
        var initialized = 0;
        var disposed = 0;
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              children: [
                _LifecycleChild(
                  key: _firstKey,
                  onInit: () => initialized += 1,
                  onDispose: () => disposed += 1,
                ),
                _LifecycleChild(
                  key: _secondKey,
                  onInit: () => initialized += 1,
                  onDispose: () => disposed += 1,
                ),
              ],
            ),
          ),
        );

        controller.next();
        await tester.pump();

        expect((initialized, disposed), (2, 1));
      },
    );

    testWidgets(
      'when an exit animates, it should dispose the child after completion',
      (tester) async {
        final controller = SequenceController();
        var disposed = 0;
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              duration: const Duration(milliseconds: 200),
              reverseDuration: const Duration(milliseconds: 200),
              nextTransition: _fade,
              children: [
                _LifecycleChild(
                  key: _firstKey,
                  onInit: () {},
                  onDispose: () => disposed += 1,
                ),
                _LifecycleChild(
                  key: _secondKey,
                  onInit: () {},
                  onDispose: () {},
                ),
              ],
            ),
          ),
        );

        controller.next();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final disposedHalfway = disposed;
        await tester.pumpAndSettle();

        expect((disposedHalfway, disposed), (0, 1));
      },
    );

    testWidgets(
      'when keepMounted is true, it should preserve inactive children',
      (tester) async {
        final controller = SequenceController();
        var initialized = 0;
        var disposed = 0;
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              keepMounted: true,
              children: [
                _LifecycleChild(
                  key: _firstKey,
                  onInit: () => initialized += 1,
                  onDispose: () => disposed += 1,
                ),
                _LifecycleChild(
                  key: _secondKey,
                  onInit: () => initialized += 1,
                  onDispose: () => disposed += 1,
                ),
              ],
            ),
          ),
        );

        controller.next();
        await tester.pump();

        expect((initialized, disposed), (2, 0));
      },
    );

    testWidgets(
      'when transition wrappers change, it should preserve kept child state',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              keepMounted: true,
              nextTransition: _fade,
              previousTransition: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              children: const [
                _CounterChild(key: _firstKey),
                SizedBox(key: _secondKey),
              ],
            ),
          ),
        );
        await tester.tap(find.text('0'));
        await tester.pump();

        controller.next();
        await tester.pumpAndSettle();
        controller.previous();
        await tester.pumpAndSettle();

        expect(find.text('1'), findsOneWidget);
      },
    );

    testWidgets(
      'when a kept child is inactive, it should disable its ticker, input, paint, and semantics',
      (tester) async {
        final controller = SequenceController();
        var taps = 0;
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              keepMounted: true,
              children: [
                Semantics(
                  label: 'Inactive step',
                  child: GestureDetector(
                    key: _firstKey,
                    onTap: () => taps += 1,
                    child: const SizedBox(width: 40, height: 40),
                  ),
                ),
                const SizedBox(key: _secondKey, width: 40, height: 40),
              ],
            ),
          ),
        );
        controller.next();
        await tester.pump();

        final tickerModes = tester
            .widgetList<TickerMode>(
              find.descendant(
                of: find.byType(Sequence),
                matching: find.byType(TickerMode, skipOffstage: false),
                skipOffstage: false,
              ),
            )
            .map((tickerMode) => tickerMode.enabled)
            .toList();
        final offstageModes = tester
            .widgetList<Offstage>(
              find.descendant(
                of: find.byType(Sequence),
                matching: find.byType(Offstage, skipOffstage: false),
                skipOffstage: false,
              ),
            )
            .map((offstage) => offstage.offstage)
            .toList();
        await tester.tap(
          find.byKey(_firstKey, skipOffstage: false),
          warnIfMissed: false,
        );
        final inactiveSemantics = find
            .bySemanticsLabel(
              'Inactive step',
            )
            .evaluate()
            .length;
        semantics.dispose();

        expect(
          [
            tickerModes,
            offstageModes,
            inactiveSemantics,
            taps,
          ],
          [
            [false],
            [true],
            0,
            0,
          ],
        );
      },
    );

    testWidgets(
      'when transitioning, it should size to the largest participant',
      (tester) async {
        final controller = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: controller,
              nextTransition: _fade,
              children: const [
                SizedBox(key: _firstKey, width: 40, height: 20),
                SizedBox(key: _secondKey, width: 100, height: 50),
              ],
            ),
          ),
        );

        controller.next();
        await tester.pump();

        expect(tester.getSize(find.byType(Sequence)), const Size(100, 50));
      },
    );

    testWidgets(
      'when retained children are inactive, it should size only to the current child',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              keepMounted: true,
              children: const [
                SizedBox(key: _firstKey, width: 40, height: 20),
                SizedBox(key: _secondKey, width: 100, height: 50),
              ],
            ),
          ),
        );

        expect(tester.getSize(find.byType(Sequence)), const Size(40, 20));
      },
    );
  });

  group('Sequence updates', () {
    testWidgets(
      'when children shrink, it should clamp to the final valid index',
      (tester) async {
        final controller = SequenceController();
        late StateSetter rebuild;
        var children = _children();
        await tester.pumpWidget(
          _testApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Sequence(
                  controller: controller,
                  children: children,
                );
              },
            ),
          ),
        );
        controller.goTo(2);
        await tester.pump();

        rebuild(() => children = _children().take(2).toList());
        await tester.pump();

        expect((controller.index, find.text('Second').evaluate().length), (1, 1));
      },
    );

    testWidgets(
      'when the controller changes, it should detach the old controller',
      (tester) async {
        final oldController = SequenceController();
        final newController = SequenceController();
        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: oldController,
              children: _children(),
            ),
          ),
        );
        oldController.next();
        await tester.pump();

        await tester.pumpWidget(
          _testApp(
            child: Sequence(
              controller: newController,
              children: _children(),
            ),
          ),
        );

        Object? error;
        try {
          oldController.next();
        } on Object catch (caught) {
          error = caught;
        }

        expect(newController.index == 1 && error is StateError, isTrue);
      },
    );

    testWidgets(
      'when a keyed child moves, it should preserve that child state',
      (tester) async {
        final controller = SequenceController();
        late StateSetter rebuild;
        var children = <Widget>[
          const _CounterChild(key: _firstKey),
          const SizedBox(key: _secondKey),
        ];
        await tester.pumpWidget(
          _testApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Sequence(
                  controller: controller,
                  keepMounted: true,
                  children: children,
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('0'));
        await tester.pump();

        rebuild(() => children = children.reversed.toList());
        await tester.pump();
        controller.next();
        await tester.pump();

        expect(find.text('1'), findsOneWidget);
      },
    );
  });
}

class _LifecycleChild extends StatefulWidget {
  const _LifecycleChild({
    required this.onInit,
    required this.onDispose,
    super.key,
  });

  final VoidCallback onInit;
  final VoidCallback onDispose;

  @override
  State<_LifecycleChild> createState() => _LifecycleChildState();
}

class _LifecycleChildState extends State<_LifecycleChild> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 40, height: 20);
  }
}

class _CounterChild extends StatefulWidget {
  const _CounterChild({super.key});

  @override
  State<_CounterChild> createState() => _CounterChildState();
}

class _CounterChildState extends State<_CounterChild> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => _count += 1),
      child: Text('$_count'),
    );
  }
}
