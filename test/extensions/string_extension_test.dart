import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('StringExtension', () {
    group('when checking whether a value contains only digits', () {
      test('when every character is a digit, it should return true', () {
        expect('0123456789'.isDigitsOnly, isTrue);
      });

      test('when the value is empty, it should return false', () {
        expect(''.isDigitsOnly, isFalse);
      });

      test('when the value contains a letter, it should return false', () {
        expect('123a'.isDigitsOnly, isFalse);
      });

      test('when the value contains whitespace, it should return false', () {
        expect('123 456'.isDigitsOnly, isFalse);
      });

      test('when the value contains a decimal point, it should return false', () {
        expect('123.45'.isDigitsOnly, isFalse);
      });

      test('when the value contains a sign, it should return false', () {
        expect('-123'.isDigitsOnly, isFalse);
      });
    });
  });
}
