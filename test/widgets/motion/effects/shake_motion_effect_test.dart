import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

const _childKey = Key('shake_child');

Widget _testApp({
  required MotionEffect effect,
  Widget child = const SizedBox(key: _childKey, width: 40, height: 20),
  bool interactive = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Motion(
          effect: effect,
          interactive: interactive,
          child: child,
        ),
      ),
    ),
  );
}

Offset _translation(WidgetTester tester) {
  final motion = tester.renderObject<RenderBox>(find.byType(Motion));
  final child = tester.renderObject<RenderBox>(find.byKey(_childKey));
  return child.localToGlobal(child.size.center(Offset.zero)) - motion.localToGlobal(motion.size.center(Offset.zero));
}

RenderBox _transitionRenderBox(WidgetTester tester) {
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

T _textMotionProperty<T>(WidgetTester tester, String name) {
  final renderObject = tester.renderObject<RenderObject>(
    find.descendant(
      of: find.byType(TextMotion),
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_OptimizedTextMotion',
      ),
    ),
  );
  final property = renderObject.toDiagnosticsNode().getProperties().singleWhere(
    (property) => property.name == name,
  );
  final value = (property as DiagnosticsProperty<T>).value;
  if (value == null) {
    throw StateError('TextMotion diagnostic $name is null.');
  }
  return value;
}

void main() {
  group('ShakeMotionEffect', () {
    test('when created, it should expose neutral motion defaults', () {
      const effect = ShakeMotionEffect(offset: Offset(6, 0));

      expect(
        (
          effect.offset,
          effect.count,
          effect.damping,
          effect.delay,
          effect.duration,
          effect.curve,
          effect.playback,
          effect.onStart,
          effect.onEnd,
        ),
        (
          const Offset(6, 0),
          3,
          1,
          Duration.zero,
          const Duration(milliseconds: 300),
          Curves.linear,
          MotionPlayback.once,
          null,
          null,
        ),
      );
    });

    test('when configured, it should declare symmetric offset bounds', () {
      const effect = ShakeMotionEffect(offset: Offset(-6, 9));

      expect(
        (effect.bounds.minimumOffset, effect.bounds.maximumOffset),
        (const Offset(-6, -9), const Offset(6, 9)),
      );
    });

    testWidgets(
      'when an offset has two axes, it should shake along that vector',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            effect: const ShakeMotionEffect(
              offset: Offset(7, -11),
              count: 1,
              damping: 0,
              duration: Duration(milliseconds: 400),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          _translation(tester),
          offsetMoreOrLessEquals(const Offset(7, -11)),
        );
      },
    );

    testWidgets(
      'when count is three, it should produce three alternating excursions',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            effect: const ShakeMotionEffect(
              offset: Offset(12, 0),
              damping: 0,
              duration: Duration(milliseconds: 600),
            ),
          ),
        );
        final translations = <double>[];
        await tester.pump(const Duration(milliseconds: 100));
        translations.add(_translation(tester).dx);
        await tester.pump(const Duration(milliseconds: 200));
        translations.add(_translation(tester).dx);
        await tester.pump(const Duration(milliseconds: 200));
        translations.add(_translation(tester).dx);

        final maximumError = <double>[
          (translations[0] - 12).abs(),
          (translations[1] + 12).abs(),
          (translations[2] - 12).abs(),
        ].reduce(math.max);
        expect(maximumError, lessThan(0.001));
      },
    );

    testWidgets(
      'when damping is one, it should linearly reduce the excursion',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            effect: const ShakeMotionEffect(
              offset: Offset(0, 12),
              count: 1,
              duration: Duration(milliseconds: 400),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(_translation(tester).dy, closeTo(6, 0.001));
      },
    );

    testWidgets(
      'when configured with a smooth damped path, it should preserve its trajectory',
      (tester) async {
        const duration = Duration(milliseconds: 1300);
        await tester.pumpWidget(
          _testApp(
            effect: const ShakeMotionEffect(
              offset: Offset(6, 0),
              duration: duration,
              curve: Curves.easeOutBack,
            ),
          ),
        );
        const sampleTimes = <Duration>[
          Duration(milliseconds: 35),
          Duration(milliseconds: 325),
          Duration(milliseconds: 650),
          Duration(milliseconds: 975),
          duration,
        ];
        var previousTime = Duration.zero;
        var maximumError = 0.0;
        for (final sampleTime in sampleTimes) {
          await tester.pump(sampleTime - previousTime);
          final timelineProgress = sampleTime.inMicroseconds / duration.inMicroseconds;
          final progress = Curves.easeOutBack.transform(timelineProgress);
          final expected = math.sin(progress * math.pi * 3) * 6 * (1 - progress);
          maximumError = math.max(
            maximumError,
            (_translation(tester) - Offset(expected, 0)).distance,
          );
          previousTime = sampleTime;
        }

        expect(maximumError, lessThan(0.001));
      },
    );

    testWidgets(
      'when playback reaches either endpoint, it should rest at the layout position',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            effect: const ShakeMotionEffect(offset: Offset(8, 4)),
          ),
        );
        final start = _translation(tester);
        await tester.pump(const Duration(milliseconds: 300));
        final end = _translation(tester);

        expect(math.max(start.distance, end.distance), lessThan(0.001));
      },
    );

    testWidgets(
      'when shaking, it should preserve layout and include displacement in paint bounds',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            effect: const ShakeMotionEffect(
              offset: Offset(20, 0),
              count: 1,
              damping: 0,
            ),
          ),
        );

        expect(
          (
            tester.getSize(find.byKey(_childKey)),
            _transitionRenderBox(tester).paintBounds,
          ),
          (
            const Size(40, 20),
            const Rect.fromLTRB(-20, 0, 60, 20),
          ),
        );
      },
    );

    testWidgets(
      'when many excursions are requested, it should include the full offset in paint bounds',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            effect: const ShakeMotionEffect(
              offset: Offset(20, 0),
              count: 64,
              damping: 0,
            ),
          ),
        );

        expect(
          _transitionRenderBox(tester).paintBounds,
          const Rect.fromLTRB(-20, 0, 60, 20),
        );
      },
    );

    testWidgets(
      'when the child moves, it should transform hit testing with it',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _testApp(
            effect: const ShakeMotionEffect(
              offset: Offset(20, 0),
              count: 1,
              damping: 0,
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
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tapAt(tester.getCenter(find.byKey(_childKey)));

        expect(taps, 1);
      },
    );

    testWidgets(
      'when used by TextMotion, it should translate each visible grapheme',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TextMotion(
                effect: ShakeMotionEffect(
                  offset: Offset(0, 10),
                  count: 1,
                  damping: 0,
                  duration: Duration(milliseconds: 200),
                ),
                child: Text('A'),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final translations = List<Offset>.of(
          _textMotionProperty<Iterable<Offset>>(
            tester,
            'characterTranslations',
          ),
        );

        expect(
          translations.single,
          offsetMoreOrLessEquals(const Offset(0, 10)),
        );
      },
    );

    for (final (:description, :offset) in <({String description, Offset offset})>[
      (description: 'horizontal offset is infinite', offset: const Offset(double.infinity, 0)),
      (description: 'vertical offset is not a number', offset: const Offset(0, double.nan)),
    ]) {
      testWidgets('when $description, it should reject mounting', (tester) async {
        await tester.pumpWidget(
          _testApp(effect: ShakeMotionEffect(offset: offset)),
        );

        expect(tester.takeException(), isA<AssertionError>());
      });
    }

    for (final count in <int>[0, -1]) {
      test('when count is $count, it should reject construction', () {
        expect(
          () => ShakeMotionEffect(
            offset: const Offset(6, 0),
            count: count,
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    }

    for (final damping in <double>[-0.1, 1.1, double.infinity]) {
      test('when damping is $damping, it should reject construction', () {
        expect(
          () => ShakeMotionEffect(
            offset: const Offset(6, 0),
            damping: damping,
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    }
  });
}
