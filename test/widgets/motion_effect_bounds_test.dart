import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Widget _testApp(MotionEffect effect) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Motion(
          effect: effect,
          child: const SizedBox(width: 40, height: 20),
        ),
      ),
    ),
  );
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

void main() {
  group('MotionEffectBounds', () {
    test('when created, it should expose neutral defaults', () {
      const bounds = MotionEffectBounds();

      expect(
        (
          bounds.minimumOffset,
          bounds.maximumOffset,
          bounds.maximumScale,
        ),
        (Offset.zero, Offset.zero, 1),
      );
    });

    test('when an effect omits bounds, it should expose null', () {
      const effect = _SampledMotionEffect();

      expect(effect.bounds, isNull);
    });

    testWidgets(
      'when a custom oscillating effect declares bounds, it should include unsampled peaks',
      (tester) async {
        await tester.pumpWidget(_testApp(const _AliasedMotionEffect()));

        expect(
          _transitionRenderBox(tester).paintBounds,
          const Rect.fromLTRB(-20, 0, 60, 20),
        );
      },
    );

    testWidgets(
      'when a custom scaling effect declares bounds, it should include unsampled growth',
      (tester) async {
        await tester.pumpWidget(
          _testApp(const _AliasedScaleMotionEffect()),
        );

        expect(
          _transitionRenderBox(tester).paintBounds,
          const Rect.fromLTRB(-20, -10, 60, 30),
        );
      },
    );

    testWidgets(
      'when sampling finds a larger extent, it should expand declared bounds',
      (tester) async {
        await tester.pumpWidget(
          _testApp(const _UnderdeclaredMotionEffect()),
        );

        expect(
          _transitionRenderBox(tester).paintBounds,
          const Rect.fromLTRB(-20, 0, 60, 20),
        );
      },
    );

    for (final (:description, :bounds) in <({String description, MotionEffectBounds bounds})>[
      (
        description: 'minimum offset is not finite',
        bounds: const MotionEffectBounds(
          minimumOffset: Offset(double.negativeInfinity, 0),
        ),
      ),
      (
        description: 'maximum offset is not finite',
        bounds: const MotionEffectBounds(
          maximumOffset: Offset(0, double.nan),
        ),
      ),
      (
        description: 'minimum horizontal offset exceeds maximum',
        bounds: const MotionEffectBounds(
          minimumOffset: Offset(2, 0),
          maximumOffset: Offset(1, 0),
        ),
      ),
      (
        description: 'minimum vertical offset exceeds maximum',
        bounds: const MotionEffectBounds(
          minimumOffset: Offset(0, 2),
          maximumOffset: Offset(0, 1),
        ),
      ),
    ]) {
      testWidgets('when $description, it should reject mounting', (
        tester,
      ) async {
        await tester.pumpWidget(
          _testApp(_BoundedMotionEffect(bounds)),
        );

        expect(tester.takeException(), isA<AssertionError>());
      });
    }

    for (final (:description, :maximumScale) in <({String description, double maximumScale})>[
      (description: 'maximum scale is negative', maximumScale: -1),
      (description: 'maximum scale is not finite', maximumScale: double.infinity),
    ]) {
      test('when $description, it should reject construction', () {
        expect(
          () => MotionEffectBounds(maximumScale: maximumScale),
          throwsA(isA<AssertionError>()),
        );
      });
    }
  });
}

class _SampledMotionEffect extends MotionEffect {
  const _SampledMotionEffect();

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.translate(x: progress * 20, y: 0);
  }
}

class _AliasedMotionEffect extends MotionEffect {
  const _AliasedMotionEffect();

  @override
  MotionEffectBounds get bounds => const MotionEffectBounds(
    minimumOffset: Offset(-20, 0),
    maximumOffset: Offset(20, 0),
  );

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.translate(
      x: math.sin(progress * math.pi * 64) * 20,
      y: 0,
    );
  }
}

class _UnderdeclaredMotionEffect extends MotionEffect {
  const _UnderdeclaredMotionEffect();

  @override
  MotionEffectBounds get bounds => const MotionEffectBounds(
    minimumOffset: Offset(-2, 0),
    maximumOffset: Offset(2, 0),
  );

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.translate(x: progress * 20, y: 0);
  }
}

class _AliasedScaleMotionEffect extends MotionEffect {
  const _AliasedScaleMotionEffect();

  @override
  MotionEffectBounds get bounds => const MotionEffectBounds(maximumScale: 2);

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.scale(1 + math.sin(progress * math.pi * 64));
  }
}

class _BoundedMotionEffect extends MotionEffect {
  const _BoundedMotionEffect(this._bounds);

  final MotionEffectBounds _bounds;

  @override
  MotionEffectBounds get bounds => _bounds;

  @override
  void apply(double progress, MotionEffectTransform transform) {}
}
