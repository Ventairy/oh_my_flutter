import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Asserts that [actual] is within [tolerance] of [expected] per RGB channel.
void _expectColorClose(Color actual, Color expected, {int tolerance = 5}) {
  final dr = ((actual.r - expected.r) * 255).abs();
  final dg = ((actual.g - expected.g) * 255).abs();
  final db = ((actual.b - expected.b) * 255).abs();
  expect(dr, lessThanOrEqualTo(tolerance),
      reason: 'R: expected ${expected.r.toStringAsFixed(3)}, got ${actual.r.toStringAsFixed(3)}');
  expect(dg, lessThanOrEqualTo(tolerance),
      reason: 'G: expected ${expected.g.toStringAsFixed(3)}, got ${actual.g.toStringAsFixed(3)}');
  expect(db, lessThanOrEqualTo(tolerance),
      reason: 'B: expected ${expected.b.toStringAsFixed(3)}, got ${actual.b.toStringAsFixed(3)}');
}

void main() {
  group('OmfOklch', () {
    // ----------------------------------------------------------------
    // Round-trip fidelity — sRGB → OKLCH → sRGB
    // ----------------------------------------------------------------
    group('round-trip fidelity', () {
      // A diverse set of colors across the sRGB gamut
      final roundTripCases = [
        const Color(0xFFFF4A4B), // Cataquí brand red
        const Color(0xFF0090FF), // Info blue
        const Color(0xFF00D757), // Success green
        const Color(0xFFFFB224), // Warning amber
        const Color(0xFFE5484D), // Error red
        const Color(0xFF00A2C7), // Cyan
        const Color(0xFF6E56CF), // Violet
        const Color(0xFF12A594), // Teal
        const Color(0xFFF76B15), // Orange
        const Color(0xFFD6409F), // Pink
        const Color(0xFFE0C500), // Yellow
        const Color(0xFF000000), // Pure black
        const Color(0xFFFFFFFF), // Pure white
        const Color(0xFF808080), // Mid gray
        const Color(0xFFFF0000), // Pure red
        const Color(0xFF00FF00), // Pure green
        const Color(0xFF0000FF), // Pure blue
        const Color(0xFFFFFF00), // Pure yellow
        const Color(0xFFFF00FF), // Pure magenta
        const Color(0xFF00FFFF), // Pure cyan
        const Color(0xFF123456), // Random dark
        const Color(0xFFABCDEF), // Random light
        const Color(0xFF1A1A1A), // Near black
        const Color(0xFFF5F5F5), // Near white
        const Color(0xFF8B4513), // Saddle brown
        const Color(0xFF2E8B57), // Sea green
        const Color(0xFF4B0082), // Indigo
        const Color(0xFFFFD700), // Gold
        const Color(0xFFC0C0C0), // Silver
        const Color(0xFF800080), // Purple
      ];

      for (final color in roundTripCases) {
        final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
        test('when round-tripping $hex, it should return a visually identical color', () {
          final oklch = OmfOklch.fromColor(color);
          final result = oklch.toColor();
          _expectColorClose(result, color);
        });
      }
    });

    // ----------------------------------------------------------------
    // Known OKLCH → sRGB reference values
    // ----------------------------------------------------------------
    group('known reference values', () {
      test('when converting OKLCH(0, 0, 0), it should return pure black', () {
        final color = OmfOklch.toColor(0, 0, 0);
        expect(color.toARGB32(), 0xFF000000);
      });

      test('when converting OKLCH(1, 0, 0), it should return pure white', () {
        final color = OmfOklch.toColor(1, 0, 0);
        expect(color.toARGB32(), 0xFFFFFFFF);
      });

      test('when converting OKLCH(0.5, 0, 0), it should return mid gray', () {
        final color = OmfOklch.toColor(0.5, 0, 0);
        expect(color.r, closeTo(color.g, 0.01));
        expect(color.g, closeTo(color.b, 0.01));
      });

      test('when converting OKLCH(0.5, 0.1, 0), it should have a reddish tint', () {
        final color = OmfOklch.toColor(0.5, 0.1, 0);
        expect(color.r, greaterThan(color.g));
        expect(color.r, greaterThan(color.b));
      });

      test('when converting OKLCH(0.5, 0.1, 0), it should have a reddish tint', () {
        final color = OmfOklch.toColor(0.5, 0.1, 0);
        expect(color.r, greaterThan(color.g));
        expect(color.r, greaterThan(color.b));
      });

      test('when converting OKLCH(0.5, 0.1, 180), it should have a cyan tint', () {
        final color = OmfOklch.toColor(0.5, 0.1, 180);
        expect(color.g, greaterThan(color.r));
        expect(color.b, greaterThan(color.r));
      });

      test('when converting OKLCH(0.5, 0.1, 270), it should have a blue tint', () {
        final color = OmfOklch.toColor(0.5, 0.1, 270);
        expect(color.b, greaterThan(color.r));
        expect(color.b, greaterThan(color.g));
      });
    });

    // ----------------------------------------------------------------
    // Gamut clipping
    // ----------------------------------------------------------------
    group('gamut clipping', () {
      test('when converting a high-chroma out-of-gamut color, it should not crash', () {
        // Chroma 0.4 is beyond sRGB gamut for most hues
        final color = OmfOklch.toColor(0.5, 0.4, 28);
        expect(color, isA<Color>());
      });

      test('when converting an extreme out-of-gamut color, it should produce a valid sRGB color', () {
        final color = OmfOklch.toColor(0.5, 0.5, 180);
        expect(color.r, inInclusiveRange(0.0, 1.0));
        expect(color.g, inInclusiveRange(0.0, 1.0));
        expect(color.b, inInclusiveRange(0.0, 1.0));
      });

      test('when converting a very dark high-chroma color, it should produce a valid sRGB color', () {
        final color = OmfOklch.toColor(0.1, 0.3, 28);
        expect(color.r, inInclusiveRange(0.0, 1.0));
        expect(color.g, inInclusiveRange(0.0, 1.0));
        expect(color.b, inInclusiveRange(0.0, 1.0));
      });
    });

    // ----------------------------------------------------------------
    // Boundary values
    // ----------------------------------------------------------------
    group('boundary values', () {
      test('when converting with hue 0, it should produce a valid color', () {
        final color = OmfOklch.toColor(0.5, 0.15, 0);
        expect(color, isA<Color>());
      });

      test('when converting with hue 360, it should produce the same as hue 0', () {
        final a = OmfOklch.toColor(0.5, 0.15, 0);
        final b = OmfOklch.toColor(0.5, 0.15, 360);
        expect(b.toARGB32(), a.toARGB32());
      });

      test('when converting with chroma 0, it should produce a gray regardless of hue', () {
        final a = OmfOklch.toColor(0.5, 0, 0);
        final b = OmfOklch.toColor(0.5, 0, 180);
        expect(b.toARGB32(), a.toARGB32());
      });

      test('when converting with lightness 0 and chroma 0, it should produce black', () {
        final a = OmfOklch.toColor(0, 0, 0);
        expect(a.toARGB32(), 0xFF000000);
      });

      test('when converting with lightness 1 and chroma 0, it should produce white', () {
        final a = OmfOklch.toColor(1, 0, 0);
        expect(a.toARGB32(), 0xFFFFFFFF);
      });
    });

    // ----------------------------------------------------------------
    // fromColor — edge cases
    // ----------------------------------------------------------------
    group('fromColor edge cases', () {
      test('when converting pure black, it should have zero lightness', () {
        final oklch = OmfOklch.fromColor(const Color(0xFF000000));
        expect(oklch.l, closeTo(0, 0.001));
      });

      test('when converting pure white, it should have full lightness', () {
        final oklch = OmfOklch.fromColor(const Color(0xFFFFFFFF));
        expect(oklch.l, closeTo(1.0, 0.001));
      });

      test('when converting a gray, it should have near-zero chroma', () {
        final oklch = OmfOklch.fromColor(const Color(0xFF808080));
        expect(oklch.c, lessThan(0.01));
      });

      test('when converting pure red, it should have a hue near 25', () {
        final oklch = OmfOklch.fromColor(const Color(0xFFFF0000));
        expect(oklch.h, closeTo(25, 5));
      });

      test('when converting pure green, it should have a hue near 140', () {
        final oklch = OmfOklch.fromColor(const Color(0xFF00FF00));
        expect(oklch.h, closeTo(140, 5));
      });

      test('when converting pure blue, it should have a hue near 265', () {
        final oklch = OmfOklch.fromColor(const Color(0xFF0000FF));
        expect(oklch.h, closeTo(265, 5));
      });
    });

    // ----------------------------------------------------------------
    // toColor (extension)
    // ----------------------------------------------------------------
    group('toColor (extension)', () {
      test('when calling toColor on an OmfOklch, it should return the same as the static method', () {
        final oklch = OmfOklch(0.65, 0.23, 28);
        final direct = OmfOklch.toColor(0.65, 0.23, 28);
        expect(oklch.toColor().toARGB32(), direct.toARGB32());
      });
    });

    // ----------------------------------------------------------------
    // Equality
    // ----------------------------------------------------------------
    group('equality', () {
      test('when two OmfOklch have the same values, they should be equal', () {
        const a = OmfOklch(0.65, 0.23, 28);
        const b = OmfOklch(0.65, 0.23, 28);
        expect(a, equals(b));
      });

      test('when two OmfOklch have different values, they should not be equal', () {
        const a = OmfOklch(0.65, 0.23, 28);
        const b = OmfOklch(0.55, 0.22, 230);
        expect(a, isNot(equals(b)));
      });

      test('when two OmfOklch have the same values, their hash codes should be equal', () {
        const a = OmfOklch(0.65, 0.23, 28);
        const b = OmfOklch(0.65, 0.23, 28);
        expect(a.hashCode, equals(b.hashCode));
      });
    });
  });
}
