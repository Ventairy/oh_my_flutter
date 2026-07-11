import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('ColorExtension', () {
    test('when lightening a color, it should lerp the color toward white by the provided amount', () {
      final color = const Color(0xFFB3B3B3).lighten(0.6);

      expect(color, equals(Color.lerp(const Color(0xFFB3B3B3), Colors.white, 0.6)));
    });

    test('when lightening by less than zero, it should clamp to the original color', () {
      final color = const Color(0xFFB3B3B3).lighten(-1);

      expect(color, equals(const Color(0xFFB3B3B3)));
    });

    test('when lightening by more than one, it should clamp to white', () {
      final color = const Color(0xFFB3B3B3).lighten(2);

      expect(color, equals(Colors.white));
    });

    test('when darkening a color, it should lerp the color toward black by the provided amount', () {
      final color = const Color(0xFFE1E1E1).darken(0.28);

      expect(color, equals(Color.lerp(const Color(0xFFE1E1E1), Colors.black, 0.28)));
    });

    test('when darkening by less than zero, it should clamp to the original color', () {
      final color = const Color(0xFFE1E1E1).darken(-1);

      expect(color, equals(const Color(0xFFE1E1E1)));
    });

    test('when darkening by more than one, it should clamp to black', () {
      final color = const Color(0xFFE1E1E1).darken(2);

      expect(color, equals(Colors.black));
    });

    // ----------------------------------------------------------------
    // toOklch
    // ----------------------------------------------------------------
    group('toOklch', () {
      test('when calling toOklch on #FF4A4B, it should produce the correct OKLCH values', () {
        final oklch = const Color(0xFFFF4A4B).toOklch();
        expect(oklch.l, closeTo(0.67, 0.01));
        expect(oklch.c, closeTo(0.217, 0.005));
        expect(oklch.h, closeTo(25, 1));
      });

      test('when calling toOklch on #0090FF, it should produce the correct OKLCH values', () {
        final oklch = const Color(0xFF0090FF).toOklch();
        expect(oklch.l, closeTo(0.649, 0.005));
        expect(oklch.c, closeTo(0.193, 0.005));
        expect(oklch.h, closeTo(252, 2));
      });

      test('when calling toOklch on #00D757, it should produce the correct OKLCH values', () {
        final oklch = const Color(0xFF00D757).toOklch();
        expect(oklch.l, closeTo(0.767, 0.005));
        expect(oklch.c, closeTo(0.222, 0.005));
        expect(oklch.h, closeTo(148, 2));
      });

      test('when calling toOklch on #000000, it should produce zero lightness and chroma', () {
        final oklch = const Color(0xFF000000).toOklch();
        expect(oklch.l, closeTo(0, 0.001));
        expect(oklch.c, closeTo(0, 0.001));
      });

      test('when calling toOklch on #FFFFFF, it should produce full lightness and zero chroma', () {
        final oklch = const Color(0xFFFFFFFF).toOklch();
        expect(oklch.l, closeTo(1.0, 0.001));
        expect(oklch.c, closeTo(0, 0.001));
      });

      test('when calling toOklch on #808080, it should produce near-zero chroma', () {
        final oklch = const Color(0xFF808080).toOklch();
        expect(oklch.c, lessThan(0.01));
      });

      test('when calling toOklch on #FF0000, it should produce a red hue near 25', () {
        final oklch = const Color(0xFFFF0000).toOklch();
        expect(oklch.h, closeTo(25, 5));
      });

      test('when calling toOklch on #00FF00, it should produce a green hue near 140', () {
        final oklch = const Color(0xFF00FF00).toOklch();
        expect(oklch.h, closeTo(140, 5));
      });

      test('when calling toOklch on #0000FF, it should produce a blue hue near 265', () {
        final oklch = const Color(0xFF0000FF).toOklch();
        expect(oklch.h, closeTo(265, 5));
      });

      test('when calling toOklch on a color, it should return the same as OmfOklch.fromColor', () {
        const color = Color(0xFFFF4A4B);
        expect(color.toOklch(), OmfOklch.fromColor(color));
      });
    });
  });
}
