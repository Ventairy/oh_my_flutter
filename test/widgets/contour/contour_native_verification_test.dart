import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;

import 'contour_native_test_harness.dart';

void main() {
  // Exercise the verified-glyph fallback independently from atlas preparation.
  setUp(() => ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared);
  tearDown(() => ContourCompositeSource.testOverride = null);

  testWidgets('when opaque glyphs support native strokes, it should use verified text rendering', (tester) async {
    final harness = ContourNativeTestHarness();
    await harness.mount(tester, amount: 3, child: ContourNativeTestHarness.glyph);
    expect(harness.diagnostic('nativeTextActive'), isTrue);
  });

  testWidgets('when a glyph has layout padding, it should verify the translated native stroke', (tester) async {
    final harness = ContourNativeTestHarness();
    await harness.mount(
      tester,
      amount: 3,
      child: const Padding(
        padding: EdgeInsets.only(left: 7, top: 4),
        child: ContourNativeTestHarness.glyph,
      ),
    );
    expect(harness.diagnostic('nativeTextActive'), isTrue);
  });

  for (final (description, child) in <(String, Widget)>[
    (
      'the glyph color is translucent',
      const Text(
        'O',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, color: Color(0x40000000)),
      ),
    ),
    (
      'a span is almost transparent',
      const Text.rich(
        TextSpan(
          style: TextStyle(fontFamily: 'Ahem', fontSize: 24, color: Color(0xFF000000)),
          children: [
            TextSpan(text: 'O'),
            TextSpan(
              text: '.',
              style: TextStyle(color: Color(0x01000000)),
            ),
          ],
        ),
      ),
    ),
    (
      'the glyph has an underline',
      const Text(
        'O',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, decoration: TextDecoration.underline),
      ),
    ),
    (
      'the glyph has its own shadow',
      const Text(
        'O',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, shadows: [Shadow(blurRadius: 3)]),
      ),
    ),
    (
      'the glyph has a painted background',
      const Text(
        'O',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, backgroundColor: Color(0xFF008000)),
      ),
    ),
    (
      'the paragraph contains a widget',
      const Text.rich(
        TextSpan(
          style: TextStyle(fontFamily: 'Ahem', fontSize: 24),
          children: [
            TextSpan(text: 'O'),
            WidgetSpan(
              child: SizedBox.square(dimension: 8, child: ColoredBox(color: Color(0xFF008000))),
            ),
          ],
        ),
      ),
    ),
    (
      'a wrapper paints behind the glyph',
      const ColoredBox(color: Color(0xFF008000), child: ContourNativeTestHarness.glyph),
    ),
    (
      'a wrapper clips the glyph',
      const ClipRect(child: ContourNativeTestHarness.glyph),
    ),
    (
      'a wrapper changes glyph opacity',
      const Opacity(opacity: .5, child: ContourNativeTestHarness.glyph),
    ),
  ]) {
    testWidgets('when $description, it should preserve captured rendering', (tester) async {
      final harness = ContourNativeTestHarness();
      await harness.mount(tester, amount: 3, child: child);
      expect(harness.diagnostic('nativeTextActive'), isFalse);
    });
  }

  testWidgets('when a glyph uses a foreground paint, it should preserve captured rendering', (tester) async {
    final harness = ContourNativeTestHarness();
    await harness.mount(
      tester,
      amount: 3,
      child: Text(
        'O',
        style: TextStyle(
          fontFamily: 'Ahem',
          fontSize: 24,
          foreground: Paint()..color = const Color(0xFF000000),
        ),
      ),
    );
    expect(harness.diagnostic('nativeTextActive'), isFalse);
  });

  for (final amount in [.5, 3.0, 8.0]) {
    testWidgets('when verified glyphs expand by $amount, it should match the native glyph stroke exactly', (
      tester,
    ) async {
      final harness = ContourNativeTestHarness();
      const style = TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFFE84A5F));
      await harness.mount(
        tester,
        pixelRatio: 3,
        amount: amount,
        child: const Text('O', style: style),
      );
      final actual = await harness.pixels(tester, pixelRatio: 4);
      await harness.mount(
        tester,
        pixelRatio: 3,
        color: const Color(0x00000000),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text('O', style: style.copyWith(color: const Color(0xFFFFFFFF))),
            Text(
              'O',
              style: style.copyWith(
                foreground: Paint()
                  ..color = const Color(0xFFFFFFFF)
                  ..style = PaintingStyle.stroke
                  ..strokeJoin = StrokeJoin.round
                  ..strokeWidth = amount * 2,
              ),
            ),
            const Text('O', style: style),
          ],
        ),
      );
      expect(actual, await harness.pixels(tester, pixelRatio: 4));
    });
  }

  testWidgets('when glyphs are imperceptibly faint, it should leave them without an opaque backing', (tester) async {
    final harness = ContourNativeTestHarness();
    const child = Text(
      'O',
      style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0x01000000)),
    );
    await harness.mount(tester, amount: 3, child: child);
    final actual = await harness.pixels(tester, pixelRatio: 4);
    await harness.mount(tester, color: const Color(0x00000000), child: child);
    expect(actual, await harness.pixels(tester, pixelRatio: 4));
  });
}
