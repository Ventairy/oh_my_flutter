import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('SkeletonFadeEffect', () {
    test(
      'when t is 0, the paint color alpha should equal the start opacity',
      () {
        const effect = SkeletonFadeEffect();
        final paint = effect.buildPaint(
          bounds: const Rect.fromLTWH(0, 0, 100, 50),
          t: 0,
          style: const SkeletonStyle(),
        );

        expect(paint.color.a, closeTo(0.4, 0.001));
      },
    );

    test(
      'when t is pi, the paint color alpha should equal the end opacity',
      () {
        const effect = SkeletonFadeEffect();
        final paint = effect.buildPaint(
          bounds: const Rect.fromLTWH(0, 0, 100, 50),
          t: math.pi,
          style: const SkeletonStyle(),
        );

        expect(paint.color.a, closeTo(1.0, 0.001));
      },
    );

    test(
      'when t is 2*pi, the paint color alpha should equal the start opacity',
      () {
        const effect = SkeletonFadeEffect();
        final paint = effect.buildPaint(
          bounds: const Rect.fromLTWH(0, 0, 100, 50),
          t: 2 * math.pi,
          style: const SkeletonStyle(),
        );

        expect(paint.color.a, closeTo(0.4, 0.001));
      },
    );

    test(
      'when t is pi/2, the paint color alpha should be the midpoint between start and end',
      () {
        const effect = SkeletonFadeEffect();
        final paint = effect.buildPaint(
          bounds: const Rect.fromLTWH(0, 0, 100, 50),
          t: math.pi / 2,
          style: const SkeletonStyle(),
        );

        expect(paint.color.a, closeTo(0.7, 0.001));
      },
    );

    test(
      'when start and end are equal, the alpha should stay constant across the loop',
      () {
        const effect = SkeletonFadeEffect(opacity: (start: 0.5, end: 0.5));

        final paintAt0 = effect.buildPaint(
          bounds: const Rect.fromLTWH(0, 0, 100, 50),
          t: 0,
          style: const SkeletonStyle(),
        );
        final paintAtPi = effect.buildPaint(
          bounds: const Rect.fromLTWH(0, 0, 100, 50),
          t: math.pi,
          style: const SkeletonStyle(),
        );
        final paintAt2Pi = effect.buildPaint(
          bounds: const Rect.fromLTWH(0, 0, 100, 50),
          t: 2 * math.pi,
          style: const SkeletonStyle(),
        );

        expect(paintAt0.color.a, closeTo(0.5, 0.001));
        expect(paintAtPi.color.a, closeTo(0.5, 0.001));
        expect(paintAt2Pi.color.a, closeTo(0.5, 0.001));
      },
    );

    test('when opacity values exceed 1.0, the alpha should clamp to 1.0', () {
      const effect = SkeletonFadeEffect(opacity: (start: 0.5, end: 1.5));
      final paint = effect.buildPaint(
        bounds: const Rect.fromLTWH(0, 0, 100, 50),
        t: math.pi,
        style: const SkeletonStyle(),
      );

      expect(paint.color.a, closeTo(1.0, 0.001));
    });

    test('when opacity values are negative, the alpha should clamp to 0.0', () {
      const effect = SkeletonFadeEffect(opacity: (start: -0.5, end: 0.5));
      final paint = effect.buildPaint(
        bounds: const Rect.fromLTWH(0, 0, 100, 50),
        t: 0,
        style: const SkeletonStyle(),
      );

      expect(paint.color.a, closeTo(0.0, 0.001));
    });

    test(
      'when a custom bone color with alpha is provided, the fade alpha should multiply the bone alpha',
      () {
        const effect = SkeletonFadeEffect();
        final paint = effect.buildPaint(
          bounds: const Rect.fromLTWH(0, 0, 100, 50),
          t: math.pi / 2,
          style: const SkeletonStyle(color: Color.fromRGBO(0, 0, 0, 0.5)),
        );

        expect(paint.color.a, closeTo(0.35, 0.001));
      },
    );

    test('when bounds are empty, buildPaint should not throw', () {
      const effect = SkeletonFadeEffect();
      final paint = effect.buildPaint(
        bounds: Rect.zero,
        t: 0,
        style: const SkeletonStyle(),
      );

      expect(paint.color.a, closeTo(0.4, 0.001));
    });

    test('when duration is customized, the effect duration should match', () {
      const effect = SkeletonFadeEffect(
        duration: Duration(milliseconds: 2000),
      );

      expect(effect.duration, const Duration(milliseconds: 2000));
    });

    test('when two effects have identical props, they should be equal', () {
      const a = SkeletonFadeEffect();
      const b = SkeletonFadeEffect();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('when opacity differs, effects should not be equal', () {
      const a = SkeletonFadeEffect(opacity: (start: 0.3, end: 1.0));
      const b = SkeletonFadeEffect(opacity: (start: 0.0, end: 0.5));

      expect(a, isNot(equals(b)));
    });

    test('when duration differs, effects should not be equal', () {
      const a = SkeletonFadeEffect(duration: Duration(milliseconds: 600));
      const b = SkeletonFadeEffect(duration: Duration(milliseconds: 1000));

      expect(a, isNot(equals(b)));
    });
  });
}
