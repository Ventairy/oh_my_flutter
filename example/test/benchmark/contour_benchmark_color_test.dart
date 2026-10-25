import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/contour/contour_benchmark_color.dart';

void main() {
  test('when black ARGB is requested, it should preserve the opaque black value', () {
    expect(ContourBenchmarkColor.parse('ff000000'), const Color(0xFF000000));
  });

  test('when mixed-case translucent ARGB is requested, it should preserve every channel', () {
    expect(ContourBenchmarkColor.parse('80Ab12Cd'), const Color(0x80AB12CD));
  });

  test('when an ARGB value has fewer than eight digits, it should reject ambiguous input', () {
    expect(() => ContourBenchmarkColor.parse('ffffff'), throwsFormatException);
  });

  test('when ARGB contains a nonhexadecimal digit, it should reject the input', () {
    expect(() => ContourBenchmarkColor.parse('ff00000g'), throwsFormatException);
  });
}
