import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('StringExtension', () {
    test('when parsing #RRGGBB, it should return a Color with full opacity', () {
      final color = '#F4F2EF'.hexToColor();

      expect(color, equals(const Color(0xFFF4F2EF)));
    });

    test('when parsing RRGGBB without hash, it should return a Color with full opacity', () {
      final color = 'F4F2EF'.hexToColor();

      expect(color, equals(const Color(0xFFF4F2EF)));
    });

    test('when parsing #AARRGGBB, it should preserve the alpha channel', () {
      final color = '#80F4F2EF'.hexToColor();

      expect(color, equals(const Color(0x80F4F2EF)));
    });

    test('when parsing an invalid hex string, it should throw a FormatException', () {
      expect(() => 'XYZXYZ'.hexToColor(), throwsFormatException);
    });
  });
}
