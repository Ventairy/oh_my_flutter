import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('SkeletonStyle', () {
    test('when defaults are used, it should expose neutral Material values', () {
      const style = SkeletonStyle();

      expect(
        (style.color, style.effect, style.shape),
        (
          const Color(0xFFE0E0E0),
          null,
          const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
        ),
      );
    });

    test('when two instances have the same fields, it should be equal', () {
      const first = SkeletonStyle(effect: SkeletonShimmerEffect());
      const second = SkeletonStyle(effect: SkeletonShimmerEffect());

      expect(
        (first == second, first.hashCode == second.hashCode),
        (true, true),
      );
    });

    test('when color differs, it should not be equal', () {
      const first = SkeletonStyle(color: Colors.blue);
      const second = SkeletonStyle(color: Colors.green);

      expect(first, isNot(second));
    });

    test('when shape differs, it should not be equal', () {
      const first = SkeletonStyle(shape: RoundedRectangleBorder());
      const second = SkeletonStyle(shape: StadiumBorder());

      expect(first, isNot(second));
    });
  });
}
