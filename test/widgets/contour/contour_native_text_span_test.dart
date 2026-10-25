import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_native_test_harness.dart';

void main() {
  testWidgets('when the stroke returns to an earlier amount, it should preserve its exact pixels', (tester) async {
    final harness = ContourNativeTestHarness();
    await harness.mount(tester, amount: .5, child: ContourNativeTestHarness.glyph);
    final original = await harness.pixels(tester, pixelRatio: 4);
    for (final amount in [8.0, 0.0, 3.0, .5]) {
      await harness.mount(tester, amount: amount, child: ContourNativeTestHarness.glyph);
    }
    expect(await harness.pixels(tester, pixelRatio: 4), original);
  });

  testWidgets('when text size changes, it should match the new native glyph stroke exactly', (tester) async {
    final harness = ContourNativeTestHarness();
    const style = TextStyle(fontFamily: 'Ahem', fontSize: 40, height: 1, color: Color(0xFFE84A5F));
    await harness.mount(tester, amount: 3, child: ContourNativeTestHarness.glyph);
    await harness.mount(tester, amount: 3, child: const Text('O', style: style));
    final actual = await harness.pixels(tester, pixelRatio: 4);
    await harness.mount(
      tester,
      color: const Color(0x00000000),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Text(
            'O',
            style: TextStyle(fontFamily: 'Ahem', fontSize: 40, height: 1, color: Color(0xFFFFFFFF)),
          ),
          Text(
            'O',
            style: style.copyWith(
              foreground: Paint()
                ..color = const Color(0xFFFFFFFF)
                ..style = PaintingStyle.stroke
                ..strokeJoin = StrokeJoin.round
                ..strokeWidth = 6,
            ),
          ),
          const Text('O', style: style),
        ],
      ),
    );
    expect(actual, await harness.pixels(tester, pixelRatio: 4));
  });
}
