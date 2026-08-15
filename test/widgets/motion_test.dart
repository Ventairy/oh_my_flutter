import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

const _childKey = Key('motion_child');

Widget _testApp({
  required Widget child,
  bool disableAnimations = false,
  bool tickersEnabled = true,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: TickerMode(
        enabled: tickersEnabled,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

RenderBox _motionRenderBox(WidgetTester tester) {
  return tester.renderObject<RenderBox>(find.byType(Motion));
}

RenderBox _motionChildRenderBox(WidgetTester tester) {
  return tester.renderObject<RenderBox>(
    find.descendant(
      of: find.byType(Motion),
      matching: find.byType(SizedBox),
    ),
  );
}

RenderBox _motionTransitionRenderBox(WidgetTester tester) {
  return tester.renderObject<RenderBox>(
    find
        .descendant(
          of: find.byType(Motion),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MotionTransition',
          ),
        )
        .first,
  );
}

Offset _visualTranslation(WidgetTester tester) {
  final motion = _motionRenderBox(tester);
  final child = _motionChildRenderBox(tester);
  return child.localToGlobal(child.size.center(Offset.zero)) - motion.localToGlobal(motion.size.center(Offset.zero));
}

double _translationY(WidgetTester tester) {
  return _visualTranslation(tester).dy;
}

double _scaleValue(WidgetTester tester) {
  final child = _motionChildRenderBox(tester);
  final left = child.localToGlobal(Offset.zero).dx;
  final right = child.localToGlobal(Offset(child.size.width, 0)).dx;
  return (right - left) / child.size.width;
}

Offset _moveTranslation(WidgetTester tester) {
  return _visualTranslation(tester);
}

T _motionProperty<T>(WidgetTester tester, String name) {
  final renderObject = tester.renderObject<RenderObject>(
    find
        .descendant(
          of: find.byType(Motion),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MotionTransition',
          ),
        )
        .first,
  );
  final property = renderObject.toDiagnosticsNode().getProperties().singleWhere((property) => property.name == name);
  final value = (property as DiagnosticsProperty<T>).value;
  if (value == null) {
    throw StateError('Motion diagnostic $name is null.');
  }
  return value;
}

double _motionOpacity(WidgetTester tester) {
  return _motionProperty<double>(tester, 'opacity');
}

T _textMotionDebugProperty<T>(WidgetTester tester, String name) {
  final renderObject = tester.renderObject<RenderObject>(
    find.descendant(
      of: find.byType(TextMotion),
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_OptimizedTextMotion',
      ),
    ),
  );
  final property = renderObject.toDiagnosticsNode().getProperties().singleWhere((property) => property.name == name);
  final value = (property as DiagnosticsProperty<T>).value;
  if (value == null) {
    throw StateError('TextMotion diagnostic $name is null.');
  }
  return value;
}

void main() {
  group('MotionPlayback', () {
    test('when playback is once, it should report isOnce', () {
      expect(MotionPlayback.once.isOnce, isTrue);
    });

    test('when playback loops, it should not report isOnce', () {
      expect(MotionPlayback.loop.isOnce, isFalse);
    });
  });

  group('MotionEffect construction', () {
    testWidgets(
      'when a custom effect is shared, it should drive Motion and TextMotion',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: _SharedMoveMotionEffect(),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));
        final motionTranslation = _moveTranslation(tester);
        final motionOpacity = _motionOpacity(tester);

        await tester.pumpWidget(
          _testApp(
            child: const TextMotion(
              effect: _SharedMoveMotionEffect(),
              child: Text('AB'),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));
        final textTranslations = List<Offset>.of(
          _textMotionDebugProperty<Iterable<Offset>>(
            tester,
            'characterTranslations',
          ),
        );
        final textOpacities = List<double>.of(
          _textMotionDebugProperty<Iterable<double>>(
            tester,
            'characterOpacities',
          ),
        );

        expect(
          (
            motionTranslation.dx,
            motionOpacity,
            textTranslations.first.dx,
            textTranslations.last.dx,
            textOpacities.first,
            textOpacities.last,
            _textMotionDebugProperty<bool>(tester, 'usesAtlas'),
          ),
          (10, 0.5, 10, 12, 0.5, 0.4, true),
        );
      },
    );

    testWidgets(
      'when an effect changes, it should update the rendered operation',
      (tester) async {
        late StateSetter rebuild;
        var begin = 20.0;
        await tester.pumpWidget(
          _testApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Motion(
                  effect: MoveMotionEffect(
                    begin: Offset(begin, 0),
                    end: Offset.zero,
                  ),
                  child: const SizedBox(width: 40, height: 20),
                );
              },
            ),
          ),
        );
        rebuild(() => begin = 40);
        await tester.pump();

        expect(_moveTranslation(tester).dx, 40);
      },
    );

    testWidgets(
      'when a custom effect moves, it should derive expanded paint bounds',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: _SharedMoveMotionEffect(),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        final renderObject = _motionTransitionRenderBox(tester);

        expect(
          renderObject.paintBounds,
          const Rect.fromLTRB(-20, 0, 60, 20),
        );
      },
    );

    testWidgets('when effects are empty, it should reject mounting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          child: const Motion.list(
            effects: <MotionEffect>[],
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      expect(tester.takeException(), isArgumentError);
    });

    testWidgets('when duration is zero, it should reject mounting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          child: const Motion(
            effect: _ScaleMotionEffect(duration: Duration.zero),
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isArgumentError,
      );
    });

    testWidgets('when delay is negative, it should reject mounting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          child: const Motion(
            effect: _ScaleMotionEffect(
              delay: Duration(milliseconds: -1),
            ),
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isArgumentError,
      );
    });

    testWidgets('when floating distance is zero, it should reject mounting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          child: const Motion(
            effect: FloatingMotionEffect(distance: 0),
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isArgumentError,
      );
    });

    testWidgets('when floating distance is not finite, it should reject mounting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          child: const Motion(
            effect: FloatingMotionEffect(distance: double.infinity),
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isArgumentError,
      );
    });

    testWidgets('when scale is not finite, it should reject mounting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          child: const Motion(
            effect: ScaleInMotionEffect(scale: double.infinity),
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isArgumentError,
      );
    });

    testWidgets('when move begin is not finite, it should reject mounting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          child: const Motion(
            effect: MoveMotionEffect(
              begin: Offset(double.infinity, 0),
              end: Offset.zero,
            ),
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isArgumentError,
      );
    });

    testWidgets('when move end is not finite, it should reject mounting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          child: const Motion(
            effect: MoveMotionEffect(
              begin: Offset.zero,
              end: Offset(0, double.infinity),
            ),
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isArgumentError,
      );
    });
  });

  group('FadeInMotionEffect', () {
    testWidgets(
      'when using defaults, it should fade from transparent to opaque',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: FadeInMotionEffect(),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        final start = _motionOpacity(tester);
        await tester.pump(const Duration(milliseconds: 150));
        final middle = _motionOpacity(tester);
        await tester.pump(const Duration(milliseconds: 150));
        final end = _motionOpacity(tester);

        expect((start, middle, end), (0, 0.5, 1));
      },
    );

    test(
      'when configured, it should expose custom playback values',
      () {
        const effect = FadeInMotionEffect(
          duration: Duration(milliseconds: 500),
          curve: Curves.easeIn,
          playback: MotionPlayback.loop,
        );

        expect(
          (effect.duration, effect.curve, effect.playback),
          (
            const Duration(milliseconds: 500),
            Curves.easeIn,
            MotionPlayback.loop,
          ),
        );
      },
    );
  });

  group('ScaleInMotionEffect', () {
    testWidgets(
      'when using defaults, it should scale from zero to the child size',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: ScaleInMotionEffect(),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        final start = _scaleValue(tester);
        await tester.pump(const Duration(milliseconds: 150));
        final middle = _scaleValue(tester);
        await tester.pump(const Duration(milliseconds: 150));
        final end = _scaleValue(tester);

        expect((start, middle, end), (0, 0.5, 1));
      },
    );

    testWidgets(
      'when custom scale and timing are provided, it should honor them',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: ScaleInMotionEffect(
                scale: 0.4,
                duration: Duration(milliseconds: 400),
                curve: Curves.easeIn,
              ),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        final progress = Curves.easeIn.transform(0.5);

        expect(
          _scaleValue(tester),
          closeTo(0.4 + (0.6 * progress), 0.01),
        );
      },
    );

    testWidgets(
      'when scaling, it should preserve the child layout size',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: ScaleInMotionEffect(),
              child: SizedBox(key: _childKey, width: 40, height: 20),
            ),
          ),
        );
        final initialSize = tester.getSize(find.byKey(_childKey));
        await tester.pump(const Duration(milliseconds: 150));

        expect(
          (initialSize, tester.getSize(find.byKey(_childKey))),
          (const Size(40, 20), const Size(40, 20)),
        );
      },
    );

    testWidgets(
      'when frames advance, it should not rebuild the scaling child',
      (tester) async {
        var builds = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: const ScaleInMotionEffect(),
              child: _BuildCountingChild(onBuild: () => builds += 1),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));

        expect(builds, 1);
      },
    );

    testWidgets(
      'when scaled outside its layout bounds, it should transform hit testing with the child',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: const ScaleInMotionEffect(
                scale: 2,
                duration: Duration(milliseconds: 100),
              ),
              interactive: true,
              child: GestureDetector(
                key: _childKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => taps += 1,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        );
        await tester.tapAt(tester.getCenter(find.byKey(_childKey)) + const Offset(30, 0));

        expect(taps, 1);
      },
    );
  });

  group('MoveMotionEffect', () {
    testWidgets(
      'when moving, it should interpolate from begin to end',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: MoveMotionEffect(
                begin: Offset(-20, 10),
                end: Offset(40, 30),
                duration: Duration(milliseconds: 400),
              ),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        final start = _moveTranslation(tester);
        await tester.pump(const Duration(milliseconds: 200));
        final middle = _moveTranslation(tester);
        await tester.pump(const Duration(milliseconds: 200));
        final end = _moveTranslation(tester);

        expect(
          (start, middle, end),
          (
            const Offset(-20, 10),
            const Offset(10, 20),
            const Offset(40, 30),
          ),
        );
      },
    );

    testWidgets(
      'when custom timing is provided, it should honor duration and curve',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: MoveMotionEffect(
                begin: Offset.zero,
                end: Offset(100, 50),
                duration: Duration(milliseconds: 200),
                curve: Curves.easeIn,
              ),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final progress = Curves.easeIn.transform(0.5);

        expect(
          _moveTranslation(tester),
          Offset(100 * progress, 50 * progress),
        );
      },
    );

    testWidgets(
      'when moving, it should preserve the child layout size',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: MoveMotionEffect(
                begin: Offset(-20, 10),
                end: Offset(40, 30),
              ),
              child: SizedBox(key: _childKey, width: 40, height: 20),
            ),
          ),
        );
        final initialSize = tester.getSize(find.byKey(_childKey));
        await tester.pump(const Duration(milliseconds: 150));

        expect(
          (initialSize, tester.getSize(find.byKey(_childKey))),
          (const Size(40, 20), const Size(40, 20)),
        );
      },
    );

    testWidgets(
      'when moving, it should transform hit testing with the child',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: const MoveMotionEffect(
                begin: Offset.zero,
                end: Offset(40, 0),
                duration: Duration(milliseconds: 100),
              ),
              interactive: true,
              child: GestureDetector(
                key: _childKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => taps += 1,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tapAt(tester.getCenter(find.byKey(_childKey)));

        expect(taps, 1);
      },
    );

    testWidgets(
      'when frames advance, it should not rebuild the moving child',
      (tester) async {
        var builds = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: const MoveMotionEffect(
                begin: Offset.zero,
                end: Offset(40, 0),
              ),
              child: _BuildCountingChild(onBuild: () => builds += 1),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));

        expect(builds, 1);
      },
    );
  });

  group('FloatingMotionEffect', () {
    testWidgets(
      'when using defaults, it should follow the balanced floating path',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: FloatingMotionEffect(),
              child: SizedBox(key: _childKey, width: 40, height: 20),
            ),
          ),
        );
        final start = _translationY(tester);
        await tester.pump(const Duration(milliseconds: 600));
        final upper = _translationY(tester);
        await tester.pump(const Duration(milliseconds: 600));
        final center = _translationY(tester);
        await tester.pump(const Duration(milliseconds: 600));
        final lower = _translationY(tester);
        await tester.pump(const Duration(milliseconds: 600));
        final end = _translationY(tester);

        expect(
          start.abs() < 0.01 &&
              (upper + 8).abs() < 0.01 &&
              center.abs() < 0.01 &&
              (lower - 8).abs() < 0.01 &&
              end.abs() < 0.01,
          isTrue,
        );
      },
    );

    testWidgets(
      'when custom distance and duration are provided, it should honor them',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: FloatingMotionEffect(
                distance: 12,
                duration: Duration(milliseconds: 800),
              ),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(_translationY(tester), closeTo(-12, 0.01));
      },
    );

    testWidgets(
      'when floating, it should preserve the child layout size',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: FloatingMotionEffect(distance: 20),
              child: SizedBox(key: _childKey, width: 40, height: 20),
            ),
          ),
        );
        final initialSize = tester.getSize(find.byKey(_childKey));
        await tester.pump(const Duration(milliseconds: 600));

        expect(
          (initialSize, tester.getSize(find.byKey(_childKey))),
          (const Size(40, 20), const Size(40, 20)),
        );
      },
    );

    testWidgets(
      'when the child moves, it should transform hit testing with it',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: const FloatingMotionEffect(
                distance: 20,
                duration: Duration(milliseconds: 400),
              ),
              interactive: true,
              child: GestureDetector(
                key: _childKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => taps += 1,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tapAt(tester.getCenter(find.byKey(_childKey)));

        expect(taps, 1);
      },
    );

    testWidgets(
      'when frames advance, it should not rebuild the child',
      (tester) async {
        var builds = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: const FloatingMotionEffect(),
              child: _BuildCountingChild(onBuild: () => builds += 1),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));

        expect(builds, 1);
      },
    );

    testWidgets(
      'when frames advance, it should not lay out the child again',
      (tester) async {
        var layouts = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: const FloatingMotionEffect(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  layouts += 1;
                  return const SizedBox(width: 40, height: 20);
                },
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));

        expect(layouts, 1);
      },
    );

    testWidgets(
      'when a cycle completes, it should continue animating seamlessly',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: FloatingMotionEffect(),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 2400));

        expect(
          _translationY(tester).abs() < 0.01 && tester.hasRunningAnimations,
          isTrue,
        );
      },
    );
  });

  group('Motion.list', () {
    testWidgets(
      'when effects have different delays, it should stagger their playback',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion.list(
              effects: [
                FadeInMotionEffect(
                  duration: Duration(milliseconds: 200),
                ),
                ScaleInMotionEffect(
                  scale: 0.5,
                  delay: Duration(milliseconds: 100),
                  duration: Duration(milliseconds: 200),
                ),
              ],
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final afterFirstDelay = (
          _motionOpacity(tester),
          _scaleValue(tester),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          afterFirstDelay == (0.5, 0.5) && (_scaleValue(tester) - 0.625).abs() < 0.01,
          isTrue,
        );
      },
    );

    testWidgets(
      'when multiple effects animate, it should use one scheduler entry',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion.list(
              effects: [
                FloatingMotionEffect(distance: 4),
                FloatingMotionEffect(distance: 6),
                FloatingMotionEffect(distance: 8),
              ],
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );

        expect(tester.binding.transientCallbackCount, 1);
      },
    );

    testWidgets(
      'when multiple effects animate, it should not rebuild the child',
      (tester) async {
        var builds = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion.list(
              effects: const [
                FadeInMotionEffect(),
                ScaleInMotionEffect(),
                MoveMotionEffect(begin: Offset.zero, end: Offset(8, 0)),
              ],
              child: _BuildCountingChild(onBuild: () => builds += 1),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));

        expect(builds, 1);
      },
    );

    testWidgets(
      'when effects are listed, it should compose them in declaration order',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion.list(
              effects: [
                MoveMotionEffect(begin: Offset(10, 0), end: Offset.zero),
                ScaleInMotionEffect(scale: 0.5),
              ],
              child: SizedBox(key: _childKey, width: 40, height: 20),
            ),
          ),
        );

        final moveThenScale = _moveTranslation(tester).dx;
        await tester.pumpWidget(
          _testApp(
            child: const Motion.list(
              effects: [
                ScaleInMotionEffect(scale: 0.5),
                MoveMotionEffect(begin: Offset(10, 0), end: Offset.zero),
              ],
              child: SizedBox(key: _childKey, width: 40, height: 20),
            ),
          ),
        );
        final scaleThenMove = _moveTranslation(tester).dx;

        expect((moveThenScale, scaleThenMove), (5, 10));
      },
    );

    testWidgets(
      'when animations are disabled, it should pin each effect to its static endpoint',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            disableAnimations: true,
            child: const Motion.list(
              effects: [
                FadeInMotionEffect(delay: Duration(seconds: 1)),
                FloatingMotionEffect(delay: Duration(seconds: 2)),
              ],
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );

        expect(
          (
            _motionOpacity(tester),
            _translationY(tester).abs() < 0.01,
            tester.hasRunningAnimations,
          ),
          (1, true, false),
        );
      },
    );
  });

  group('Motion interaction', () {
    testWidgets(
      'when interaction uses its default, it should ignore taps during playback',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: const FadeInMotionEffect(
                duration: Duration(milliseconds: 100),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps += 1,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(GestureDetector), warnIfMissed: false);

        expect(taps, 0);
      },
    );

    testWidgets(
      'when interaction is enabled, it should accept taps during playback',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: const FadeInMotionEffect(
                duration: Duration(milliseconds: 100),
              ),
              interactive: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps += 1,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(GestureDetector), warnIfMissed: false);

        expect(taps, 1);
      },
    );

    testWidgets(
      'when disabled playback completes, it should accept taps again',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: const FadeInMotionEffect(
                duration: Duration(milliseconds: 100),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps += 1,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byType(GestureDetector));

        expect(taps, 1);
      },
    );

    testWidgets(
      'when an effect is delayed, it should ignore taps before playback',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: const FadeInMotionEffect(
                delay: Duration(milliseconds: 100),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps += 1,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(GestureDetector), warnIfMissed: false);

        expect(taps, 0);
      },
    );

    testWidgets(
      'when interaction is enabled during a delay, it should accept taps',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: const FadeInMotionEffect(
                delay: Duration(milliseconds: 100),
              ),
              interactive: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps += 1,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(GestureDetector));

        expect(taps, 1);
      },
    );

    testWidgets(
      'when a remaining effect is delayed, it should keep ignoring taps',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion.list(
              effects: const <MotionEffect>[
                FadeInMotionEffect(
                  duration: Duration(milliseconds: 100),
                ),
                ScaleInMotionEffect(
                  delay: Duration(milliseconds: 200),
                  duration: Duration(milliseconds: 100),
                ),
              ],
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps += 1,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));
        await tester.tap(find.byType(GestureDetector), warnIfMissed: false);

        expect(taps, 0);
      },
    );

    testWidgets(
      'when one of multiple effects remains active, it should keep ignoring taps',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion.list(
              effects: const [
                FadeInMotionEffect(
                  duration: Duration(milliseconds: 100),
                ),
                ScaleInMotionEffect(
                  duration: Duration(milliseconds: 200),
                ),
              ],
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps += 1,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byType(GestureDetector), warnIfMissed: false);

        expect(taps, 0);
      },
    );

    testWidgets(
      'when reduced motion skips playback, it should accept taps',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _testApp(
            disableAnimations: true,
            child: Motion(
              effect: const FadeInMotionEffect(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps += 1,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        );
        await tester.tap(find.byType(GestureDetector));

        expect(taps, 1);
      },
    );
  });

  group('MotionController', () {
    testWidgets(
      'when a one-shot motion finished, it should replay from the start',
      (tester) async {
        final controller = MotionController();
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              controller: controller,
              effect: const _ScaleMotionEffect(
                duration: Duration(milliseconds: 100),
              ),
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        controller.play();
        await tester.pump();

        expect(_scaleValue(tester), 0);
      },
    );

    testWidgets(
      'when play interrupts an effect, it should restart its configured delay',
      (tester) async {
        final controller = MotionController();
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              controller: controller,
              effect: const _ScaleMotionEffect(
                duration: Duration(milliseconds: 100),
                delay: Duration(milliseconds: 100),
              ),
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));

        controller.play();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 99));

        expect(
          (_scaleValue(tester), tester.hasRunningAnimations),
          (0, false),
        );
      },
    );

    testWidgets(
      'when play restarts a motion list, it should preserve independent delays',
      (tester) async {
        final controller = MotionController();
        final events = <String>[];
        await tester.pumpWidget(
          _testApp(
            child: Motion.list(
              controller: controller,
              effects: [
                FadeInMotionEffect(
                  duration: const Duration(milliseconds: 100),
                  onStart: () => events.add('first'),
                ),
                ScaleInMotionEffect(
                  duration: const Duration(milliseconds: 100),
                  delay: const Duration(milliseconds: 50),
                  onStart: () => events.add('second'),
                ),
              ],
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));
        events.clear();

        controller.play();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 49));
        await tester.pump(const Duration(milliseconds: 1));

        expect(events, ['first', 'second']);
      },
    );

    testWidgets(
      'when animations are disabled, it should replay the lifecycle at the endpoint',
      (tester) async {
        final controller = MotionController();
        final events = <String>[];
        await tester.pumpWidget(
          _testApp(
            disableAnimations: true,
            child: Motion(
              controller: controller,
              effect: FadeInMotionEffect(
                onStart: () => events.add('start'),
                onEnd: () => events.add('end'),
              ),
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        );
        events.clear();

        controller.play();
        await tester.pump();

        expect(
          (events.join(','), _motionOpacity(tester)),
          ('start,end', 1.0),
        );
      },
    );

    testWidgets(
      'when a looping motion is playing, it should restart the cycle',
      (tester) async {
        final controller = MotionController();
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              controller: controller,
              effect: const FloatingMotionEffect(
                distance: 8,
                duration: Duration(milliseconds: 100),
              ),
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 25));

        controller.play();
        await tester.pump();

        expect(_translationY(tester), 0);
      },
    );

    testWidgets(
      'when replay starts, it should disable interaction again',
      (tester) async {
        final controller = MotionController();
        var taps = 0;
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              controller: controller,
              effect: const FadeInMotionEffect(
                duration: Duration(milliseconds: 100),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps += 1,
                child: const SizedBox(width: 40, height: 40),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byType(GestureDetector));

        controller.play();
        await tester.pump();
        await tester.tap(
          find.byType(GestureDetector),
          warnIfMissed: false,
        );

        expect(taps, 1);
      },
    );
  });

  group('Motion playback', () {
    testWidgets(
      'when built-in transforms animate, it should not use frame-rebuilding transition widgets',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Stack(
              children: [
                Motion(
                  effect: ScaleInMotionEffect(),
                  child: SizedBox(width: 4, height: 4),
                ),
                Motion(
                  effect: MoveMotionEffect(begin: Offset.zero, end: Offset(4, 0)),
                  child: SizedBox(width: 4, height: 4),
                ),
                Motion(
                  effect: FloatingMotionEffect(),
                  child: SizedBox(width: 4, height: 4),
                ),
              ],
            ),
          ),
        );
        final frameRebuildingTransitions = find.descendant(
          of: find.byType(Motion),
          matching: find.byWidgetPredicate(
            (widget) => widget is AnimatedBuilder || widget is ScaleTransition,
          ),
        );

        expect(frameRebuildingTransitions, findsNothing);
      },
    );

    testWidgets(
      'when many motions animate, it should share one scheduled frame callback',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: Stack(
              children: List<Widget>.generate(
                200,
                (_) => const Motion(
                  effect: FloatingMotionEffect(),
                  child: SizedBox(width: 4, height: 4),
                ),
              ),
            ),
          ),
        );

        expect(tester.binding.transientCallbackCount, 1);
      },
    );

    testWidgets(
      'when many motions are ticker-muted, it should schedule no frame callbacks',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            tickersEnabled: false,
            child: Stack(
              children: List<Widget>.generate(
                200,
                (_) => const Motion(
                  effect: FloatingMotionEffect(),
                  child: SizedBox(width: 4, height: 4),
                ),
              ),
            ),
          ),
        );

        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets(
      'when many one-shot motions finish together, it should complete every motion and stop scheduling',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: Stack(
              children: List<Widget>.generate(
                200,
                (_) => const Motion(
                  effect: FadeInMotionEffect(
                    duration: Duration(milliseconds: 100),
                  ),
                  child: SizedBox(width: 4, height: 4),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final transitions = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_MotionTransition',
        );
        final opacities = List<double>.generate(
          transitions.evaluate().length,
          (index) {
            final renderObject = tester.renderObject<RenderObject>(
              transitions.at(index),
            );
            final property = renderObject.toDiagnosticsNode().getProperties().singleWhere(
              (property) => property.name == 'opacity',
            );
            return (property as DiagnosticsProperty<double>).value!;
          },
          growable: false,
        );

        expect(
          opacities.every((opacity) => opacity == 1) && tester.binding.transientCallbackCount == 0,
          isTrue,
        );
      },
    );

    testWidgets(
      'when delay is pending, it should stay at the start without an active ticker',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: _ScaleMotionEffect(
                duration: Duration(milliseconds: 100),
                delay: Duration(milliseconds: 100),
              ),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 99));

        expect(
          (
            _scaleValue(tester),
            tester.hasRunningAnimations,
          ),
          (0, false),
        );
      },
    );

    testWidgets(
      'when delay elapses, it should start the motion',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: _ScaleMotionEffect(
                duration: Duration(milliseconds: 100),
                delay: Duration(milliseconds: 100),
              ),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          _scaleValue(tester),
          closeTo(0.5, 0.01),
        );
      },
    );

    testWidgets(
      'when rebuilding during delay, it should not restart the wait',
      (tester) async {
        late StateSetter rebuild;
        await tester.pumpWidget(
          _testApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return const Motion(
                  effect: _ScaleMotionEffect(
                    duration: Duration(milliseconds: 100),
                    delay: Duration(milliseconds: 100),
                  ),
                  child: SizedBox(width: 40, height: 20),
                );
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        rebuild(() {});
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          _scaleValue(tester),
          closeTo(0.5, 0.01),
        );
      },
    );

    testWidgets(
      'when delay changes while pending, it should restart the wait',
      (tester) async {
        late StateSetter rebuild;
        var delay = const Duration(milliseconds: 100);
        await tester.pumpWidget(
          _testApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Motion(
                  effect: _ScaleMotionEffect(
                    duration: const Duration(milliseconds: 100),
                    delay: delay,
                  ),
                  child: const SizedBox(width: 40, height: 20),
                );
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        rebuild(() => delay = const Duration(milliseconds: 200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 199));

        expect(
          (
            _scaleValue(tester),
            tester.hasRunningAnimations,
          ),
          (0, false),
        );
      },
    );

    testWidgets(
      'when delay changes after playback starts, it should not restart motion',
      (tester) async {
        late StateSetter rebuild;
        var delay = const Duration(milliseconds: 100);
        await tester.pumpWidget(
          _testApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Motion(
                  effect: _ScaleMotionEffect(
                    duration: const Duration(milliseconds: 100),
                    delay: delay,
                  ),
                  child: const SizedBox(width: 40, height: 20),
                );
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 25));
        rebuild(() => delay = const Duration(milliseconds: 500));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 25));

        expect(
          _scaleValue(tester),
          closeTo(0.5, 0.01),
        );
      },
    );

    testWidgets(
      'when a custom curve is provided, it should curve the effect animation',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: _ScaleMotionEffect(
                duration: Duration(milliseconds: 100),
                curve: Curves.easeIn,
              ),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          _scaleValue(tester),
          closeTo(Curves.easeIn.transform(0.5), 0.01),
        );
      },
    );

    testWidgets(
      'when one-shot motion completes, it should hold the final value and stop',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: _ScaleMotionEffect(
                duration: Duration(milliseconds: 100),
              ),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 101));

        expect(
          (
            _scaleValue(tester),
            tester.hasRunningAnimations,
          ),
          (1, false),
        );
      },
    );

    testWidgets(
      'when a one-shot effect updates, it should preserve its progress',
      (tester) async {
        late StateSetter rebuild;
        var duration = const Duration(milliseconds: 100);
        await tester.pumpWidget(
          _testApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Motion(
                  effect: _ScaleMotionEffect(duration: duration),
                  child: const SizedBox(width: 40, height: 20),
                );
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        final progressBeforeUpdate = _scaleValue(tester);
        rebuild(() => duration = const Duration(milliseconds: 200));
        await tester.pump();

        expect(
          _scaleValue(tester),
          closeTo(progressBeforeUpdate, 0.01),
        );
      },
    );

    testWidgets(
      'when a one-shot motion receives a new key, it should replay from the start',
      (tester) async {
        late StateSetter rebuild;
        var motionKey = const ValueKey(1);
        await tester.pumpWidget(
          _testApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Motion(
                  effect: const _ScaleMotionEffect(
                    duration: Duration(milliseconds: 100),
                  ),
                  key: motionKey,
                  child: const SizedBox(width: 40, height: 20),
                );
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        rebuild(() => motionKey = const ValueKey(2));
        await tester.pump();

        expect(_scaleValue(tester), 0);
      },
    );

    testWidgets(
      'when ticker mode is disabled, it should suspend loop progress',
      (tester) async {
        late StateSetter rebuild;
        var tickersEnabled = true;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return _testApp(
                tickersEnabled: tickersEnabled,
                child: const Motion(
                  effect: FloatingMotionEffect(),
                  child: SizedBox(width: 40, height: 20),
                ),
              );
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        rebuild(() => tickersEnabled = false);
        await tester.pump();
        final progressBeforeWaiting = _translationY(tester);
        await tester.pump(const Duration(milliseconds: 600));

        expect(
          (_translationY(tester) - progressBeforeWaiting).abs() < 0.01 && tester.binding.transientCallbackCount == 0,
          isTrue,
        );
      },
    );

    testWidgets(
      'when motion is disposed, it should stop scheduling animation frames',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: FloatingMotionEffect(),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pumpWidget(_testApp(child: const SizedBox.shrink()));

        expect(tester.hasRunningAnimations, isFalse);
      },
    );

    testWidgets(
      'when motion is disposed during delay, it should cancel the pending start',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const Motion(
              effect: FloatingMotionEffect(delay: Duration(seconds: 1)),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pumpWidget(_testApp(child: const SizedBox.shrink()));
        await tester.pump(const Duration(seconds: 1));

        expect(tester.hasRunningAnimations, isFalse);
      },
    );
  });

  group('MotionEffect lifecycle callbacks', () {
    testWidgets(
      'when an effect is waiting for its delay, it should not fire callbacks',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: FadeInMotionEffect(
                delay: const Duration(milliseconds: 100),
                duration: const Duration(milliseconds: 100),
                onStart: () => events.add('start'),
                onEnd: () => events.add('end'),
              ),
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 99));

        expect(events, isEmpty);
      },
    );

    testWidgets(
      'when an effect starts after its delay, it should fire onStart',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: FadeInMotionEffect(
                delay: const Duration(milliseconds: 100),
                duration: const Duration(milliseconds: 100),
                onStart: () => events.add('start'),
                onEnd: () => events.add('end'),
              ),
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(events, <String>['start']);
      },
    );

    testWidgets(
      'when a one-shot effect completes, it should fire onEnd',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: FadeInMotionEffect(
                duration: const Duration(milliseconds: 100),
                onStart: () => events.add('start'),
                onEnd: () => events.add('end'),
              ),
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(events, <String>['start', 'end']);
      },
    );

    testWidgets(
      'when effects complete independently, it should fire each lifecycle independently',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(
          _testApp(
            child: Motion.list(
              effects: <MotionEffect>[
                FadeInMotionEffect(
                  duration: const Duration(milliseconds: 100),
                  onStart: () => events.add('first start'),
                  onEnd: () => events.add('first end'),
                ),
                ScaleInMotionEffect(
                  delay: const Duration(milliseconds: 50),
                  duration: const Duration(milliseconds: 100),
                  onStart: () => events.add('second start'),
                  onEnd: () => events.add('second end'),
                ),
              ],
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          events,
          <String>['first start', 'second start', 'first end', 'second end'],
        );
      },
    );

    testWidgets(
      'when a looping effect completes cycles, it should fire onStart only once',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: FloatingMotionEffect(
                duration: const Duration(milliseconds: 100),
                onStart: () => events.add('start'),
              ),
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(events, <String>['start']);
      },
    );

    testWidgets(
      'when ticker mode pauses an effect, it should wait to fire onStart',
      (tester) async {
        late StateSetter rebuild;
        var tickersEnabled = false;
        final events = <String>[];
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return _testApp(
                tickersEnabled: tickersEnabled,
                child: Motion(
                  effect: FadeInMotionEffect(
                    duration: const Duration(milliseconds: 100),
                    onStart: () => events.add('start'),
                    onEnd: () => events.add('end'),
                  ),
                  child: const SizedBox(width: 40, height: 20),
                ),
              );
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        rebuild(() => tickersEnabled = true);
        await tester.pump();

        expect(events, <String>['start']);
      },
    );

    testWidgets(
      'when a playing effect rebuilds, it should not replay onStart',
      (tester) async {
        late StateSetter rebuild;
        final events = <String>[];
        await tester.pumpWidget(
          _testApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Motion(
                  effect: FadeInMotionEffect(
                    duration: const Duration(seconds: 1),
                    onStart: () => events.add('start'),
                  ),
                  child: const SizedBox(width: 40, height: 20),
                );
              },
            ),
          ),
        );
        rebuild(() {});
        await tester.pump();

        expect(events, <String>['start']);
      },
    );

    testWidgets(
      'when a playing effect is disposed, it should not fire onEnd',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: FadeInMotionEffect(
                duration: const Duration(seconds: 1),
                onStart: () => events.add('start'),
                onEnd: () => events.add('end'),
              ),
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pumpWidget(_testApp(child: const SizedBox.shrink()));
        await tester.pump(const Duration(seconds: 1));

        expect(events, <String>['start']);
      },
    );

    testWidgets(
      'when a pending effect is disposed, it should not fire callbacks',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              effect: FadeInMotionEffect(
                delay: const Duration(seconds: 1),
                onStart: () => events.add('start'),
                onEnd: () => events.add('end'),
              ),
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pumpWidget(_testApp(child: const SizedBox.shrink()));
        await tester.pump(const Duration(seconds: 1));

        expect(events, isEmpty);
      },
    );

    testWidgets(
      'when a one-shot effect is skipped for reduced motion, it should complete its lifecycle',
      (tester) async {
        final events = <String>[];
        await tester.pumpWidget(
          _testApp(
            disableAnimations: true,
            child: Motion(
              effect: FadeInMotionEffect(
                delay: const Duration(seconds: 1),
                onStart: () => events.add('start'),
                onEnd: () => events.add('end'),
              ),
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        );

        expect(events, <String>['start', 'end']);
      },
    );
  });

  group('Motion accessibility', () {
    testWidgets(
      'when animations are disabled, it should pin one-shot motion at the end',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            disableAnimations: true,
            child: const Motion(
              effect: _ScaleMotionEffect(delay: Duration(seconds: 1)),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );

        expect(
          (
            _scaleValue(tester),
            tester.hasRunningAnimations,
          ),
          (1, false),
        );
      },
    );

    testWidgets(
      'when reduced motion is turned off, it should not replay a skipped one-shot',
      (tester) async {
        late StateSetter rebuild;
        var disableAnimations = true;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return _testApp(
                disableAnimations: disableAnimations,
                child: const Motion(
                  effect: _ScaleMotionEffect(),
                  child: SizedBox(width: 40, height: 20),
                ),
              );
            },
          ),
        );
        rebuild(() => disableAnimations = false);
        await tester.pump();

        expect(
          (
            _scaleValue(tester),
            tester.hasRunningAnimations,
          ),
          (1, false),
        );
      },
    );

    testWidgets(
      'when animations are disabled, it should pin looping motion at rest',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            disableAnimations: true,
            child: const Motion(
              effect: FloatingMotionEffect(),
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );

        expect(
          (_translationY(tester).abs() < 0.01, tester.hasRunningAnimations),
          (true, false),
        );
      },
    );
  });
}

class _ScaleMotionEffect extends ScaleInMotionEffect {
  const _ScaleMotionEffect({
    super.delay,
    super.duration,
    super.curve,
  }) : super(scale: 0);
}

class _SharedMoveMotionEffect extends MotionEffect {
  const _SharedMoveMotionEffect();

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..fade(progress)
      ..translate(x: 20 * (1 - progress), y: 0);
  }
}

class _BuildCountingChild extends StatelessWidget {
  const _BuildCountingChild({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const SizedBox(width: 40, height: 20);
  }
}
