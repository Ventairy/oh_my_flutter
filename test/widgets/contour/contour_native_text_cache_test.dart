import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_native_test_harness.dart';

void main() {
  testWidgets('when a previous glyph returns, it should reuse the accepted backing', (tester) async {
    final harness = ContourNativeTestHarness();
    await harness.mount(tester, amount: 3, child: ContourNativeTestHarness.glyph);
    await harness.mount(
      tester,
      amount: 3,
      child: const Text(
        'OO',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFFE84A5F)),
      ),
    );
    final captures = harness.captureCount;
    await harness.mount(tester, amount: 3, child: ContourNativeTestHarness.glyph);
    expect(harness.captureCount, captures);
  });

  testWidgets('when the accepted cache reaches capacity, it should evict the least recently used glyph', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    for (var index = 0; index < 64; index++) {
      await harness.mount(
        tester,
        amount: 3,
        child: Text(
          'O',
          style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFF000000 + index)),
        ),
      );
    }
    await harness.mount(
      tester,
      amount: 3,
      child: const Text(
        'O',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFF000000)),
      ),
    );
    await harness.mount(
      tester,
      amount: 3,
      child: const Text(
        'O',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFF000040)),
      ),
    );
    final before = harness.captureCount;
    await harness.mount(
      tester,
      amount: 3,
      child: const Text(
        'O',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFF000000)),
      ),
    );
    final retained = harness.captureCount;
    await harness.mount(
      tester,
      amount: 3,
      child: const Text(
        'O',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFF000001)),
      ),
    );
    expect(
      retained == before && harness.captureCount > retained && harness.diagnostic('nativeTextCacheEntries') == 64,
      isTrue,
    );
  });

  testWidgets('when retained glyph geometry reaches the byte budget, it should evict earlier backings', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    // Separate tiny glyphs keep the painted area small while retaining many
    // independent curves. Changing only the opaque color produces new keys.
    final text = List<String>.filled(2000, 'O ').join();
    for (var index = 0; index < 10; index++) {
      await harness.mount(
        tester,
        amount: 1,
        child: Text(
          text,
          style: TextStyle(fontFamily: 'Ahem', fontSize: 1, height: 2, color: Color(0xFF000000 + index)),
        ),
      );
    }
    final entries = harness.diagnostic('nativeTextCacheEntries')! as int;
    final bytes = harness.diagnostic('nativeTextCacheBytes')! as int;
    expect(
      entries > 0 && entries < 10 && bytes > 0 && bytes <= 8 * 1024 * 1024,
      isTrue,
      reason: 'Retained entries: $entries, estimated bytes: $bytes.',
    );
  });
}
