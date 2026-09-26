import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Widget _testApp({required Widget child, bool disableAnimations = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

double _motionOpacity(WidgetTester tester) {
  final renderObject = tester.renderObject<RenderObject>(
    find.descendant(
      of: find.byType(Motion),
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_MotionTransition',
      ),
    ),
  );
  final property = renderObject.toDiagnosticsNode().getProperties().singleWhere(
    (property) => property.name == 'opacity',
  );
  return (property as DiagnosticsProperty<double>).value!;
}

double _textOpacity(WidgetTester tester) {
  final renderObject = tester.renderObject<RenderObject>(
    find.descendant(
      of: find.byType(TextMotion),
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_OptimizedTextMotion',
      ),
    ),
  );
  final property = renderObject.toDiagnosticsNode().getProperties().singleWhere(
    (property) => property.name == 'characterOpacities',
  );
  return (property as DiagnosticsProperty<Iterable<double>>).value!.single;
}

void main() {
  group('PulseFadeMotionEffect', () {
    test('when created, it should use neutral looping defaults', () {
      const effect = PulseFadeMotionEffect();

      expect(
        (effect.minOpacity, effect.delay, effect.duration, effect.curve, effect.playback),
        (0.5, Duration.zero, const Duration(seconds: 2), Curves.linear, MotionPlayback.loop),
      );
    });

    testWidgets('when using defaults, it should dim and restore smoothly', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: const Motion(
            effect: PulseFadeMotionEffect(),
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );
      final start = _motionOpacity(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final quarter = _motionOpacity(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final middle = _motionOpacity(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final threeQuarters = _motionOpacity(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final end = _motionOpacity(tester);

      expect(
        [start, quarter, middle, threeQuarters, end],
        [
          closeTo(1, 0.001),
          closeTo(0.75, 0.001),
          closeTo(0.5, 0.001),
          closeTo(0.75, 0.001),
          closeTo(1, 0.001),
        ],
      );
    });

    testWidgets('when configured, it should use the chosen fade depth and cycle duration', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: const Motion(
            effect: PulseFadeMotionEffect(
              minOpacity: 0.2,
              duration: Duration(milliseconds: 400),
            ),
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(_motionOpacity(tester), closeTo(0.2, 0.001));
    });

    testWidgets('when a cycle ends, it should keep looping without an opacity jump', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: const Motion(
            effect: PulseFadeMotionEffect(),
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      final boundary = _motionOpacity(tester);
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        boundary == 1 && (_motionOpacity(tester) - 0.75).abs() < 0.001 && tester.hasRunningAnimations,
        isTrue,
      );
    });

    testWidgets('when reduced motion is enabled, it should stay fully visible', (tester) async {
      await tester.pumpWidget(
        _testApp(
          disableAnimations: true,
          child: const Motion(
            effect: PulseFadeMotionEffect(minOpacity: 0),
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );

      expect((_motionOpacity(tester), tester.hasRunningAnimations), (1, false));
    });

    testWidgets('when used by TextMotion, it should fade a visible character', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: const TextMotion(
            effect: PulseFadeMotionEffect(),
            child: Text('A'),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(_textOpacity(tester), closeTo(0.5, 0.001));
    });

    for (final opacity in <double>[-0.1, 1.1, double.nan]) {
      test('when minOpacity is $opacity, it should reject construction', () {
        expect(() => PulseFadeMotionEffect(minOpacity: opacity), throwsA(isA<AssertionError>()));
      });
    }
  });
}
