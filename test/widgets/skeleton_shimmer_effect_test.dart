import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('SkeletonShimmerEffect', () {
    test(
      'when defaults are used, it should build a neutral shimmer gradient',
      () {
        const effect = SkeletonShimmerEffect();
        final paint = effect.buildPaint(
          bounds: const Rect.fromLTWH(0, 0, 100, 50),
          t: 0,
          style: const SkeletonStyle(),
        );

        expect(paint.shader, isA<ui.Gradient>());
      },
    );

    test('when color is set, it should override the theme color', () {
      const effect = SkeletonShimmerEffect(
        color: Colors.red,
      );
      final paint = effect.buildPaint(
        bounds: const Rect.fromLTWH(0, 0, 100, 50),
        t: 0,
        style: const SkeletonStyle(),
      );

      expect(paint.shader, isA<ui.Gradient>());
    });

    test('when angle is zero, the gradient is horizontal', () {
      const effect = SkeletonShimmerEffect();
      final paint = effect.buildPaint(
        bounds: const Rect.fromLTWH(0, 0, 100, 50),
        t: 0,
        style: const SkeletonStyle(),
      );

      expect(paint.shader, isA<ui.Gradient>());
    });

    test('when angle is pi/2, the gradient is vertical', () {
      const effect = SkeletonShimmerEffect(angle: math.pi / 2);
      final paint = effect.buildPaint(
        bounds: const Rect.fromLTWH(0, 0, 100, 50),
        t: 0,
        style: const SkeletonStyle(),
      );

      expect(paint.shader, isA<ui.Gradient>());
    });

    test('when bounds are empty, buildPaint should not throw', () {
      const effect = SkeletonShimmerEffect();
      final paint = effect.buildPaint(
        bounds: Rect.zero,
        t: 0,
        style: const SkeletonStyle(),
      );

      expect(paint.shader, isA<ui.Gradient>());
    });

    test('when angle is zero, two equal effects should be equal', () {
      const a = SkeletonShimmerEffect();
      const b = SkeletonShimmerEffect();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('when color differs, effects should not be equal', () {
      const a = SkeletonShimmerEffect(
        color: Colors.blue,
      );
      const b = SkeletonShimmerEffect(
        color: Colors.green,
      );

      expect(a, isNot(equals(b)));
    });

    test('when angle differs, effects should not be equal', () {
      const a = SkeletonShimmerEffect(angle: 0);
      const b = SkeletonShimmerEffect(angle: math.pi / 4);

      expect(a, isNot(equals(b)));
    });

    test('when duration is customized, the effect should expose it', () {
      const effect = SkeletonShimmerEffect(
        duration: Duration(milliseconds: 900),
      );

      expect(effect.duration, const Duration(milliseconds: 900));
    });

    test('when duration differs, effects should not be equal', () {
      const a = SkeletonShimmerEffect(
        duration: Duration(milliseconds: 900),
      );
      const b = SkeletonShimmerEffect(
        duration: Duration(milliseconds: 1500),
      );

      expect(a, isNot(equals(b)));
    });
  });
}
