import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('DoubleExtension', () {
    test('when the value is positive and finite, it should return true', () {
      expect(1.0.isPositiveFinite, isTrue);
    });

    test('when the value is zero, it should return false', () {
      expect(0.0.isPositiveFinite, isFalse);
    });

    test('when the value is negative zero, it should return false', () {
      expect((-0.0).isPositiveFinite, isFalse);
    });

    test('when the value is negative and finite, it should return false', () {
      expect((-1.0).isPositiveFinite, isFalse);
    });

    test('when the value is positive infinity, it should return false', () {
      expect(double.infinity.isPositiveFinite, isFalse);
    });

    test('when the value is negative infinity, it should return false', () {
      expect(double.negativeInfinity.isPositiveFinite, isFalse);
    });

    test('when the value is NaN, it should return false', () {
      expect(double.nan.isPositiveFinite, isFalse);
    });
  });
}
