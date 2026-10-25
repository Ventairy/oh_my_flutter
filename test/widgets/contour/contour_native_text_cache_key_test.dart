import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_native_custom_color.dart';
import 'contour_native_custom_locale.dart';
import 'contour_native_test_harness.dart';

void main() {
  testWidgets('when a text key exceeds its byte budget, it should generate without retaining the key', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    await harness.mount(
      tester,
      amount: 3,
      child: Text(
        'O${List<String>.filled(40000, '\u200B').join()}',
        softWrap: false,
        overflow: TextOverflow.visible,
        style: const TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFF000000)),
      ),
    );
    expect((harness.diagnostic('contourReady'), harness.diagnostic('nativeTextCacheEntries')), (true, 0));
  });

  testWidgets('when a span tree is too deep to share, it should generate without retaining the key', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    InlineSpan span = const TextSpan(text: 'O');
    for (var depth = 0; depth < 70; depth++) {
      span = TextSpan(children: [span]);
    }
    await harness.mount(
      tester,
      amount: 3,
      child: Text.rich(
        span,
        style: const TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFF000000)),
      ),
    );
    expect((harness.diagnostic('contourReady'), harness.diagnostic('nativeTextCacheEntries')), (true, 0));
  });

  testWidgets(
    'when a paragraph contains too many spans to share, it should generate without retaining the key',
    (
      tester,
    ) async {
      final harness = ContourNativeTestHarness();
      await harness.mount(
        tester,
        amount: 3,
        child: Text.rich(
          TextSpan(
            text: 'O',
            children: List<TextSpan>.filled(300, const TextSpan(text: '')),
          ),
          style: const TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFF000000)),
        ),
      );
      expect((harness.diagnostic('contourReady'), harness.diagnostic('nativeTextCacheEntries')), (true, 0));
    },
  );

  testWidgets('when font fallback names exceed the key budget, it should generate without retaining the key', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    await harness.mount(
      tester,
      amount: 3,
      child: Text(
        'O',
        style: TextStyle(
          fontFamily: 'Ahem',
          fontFamilyFallback: [List<String>.filled(40000, 'x').join()],
          fontSize: 24,
          height: 1,
          color: const Color(0xFF000000),
        ),
      ),
    );
    expect((harness.diagnostic('contourReady'), harness.diagnostic('nativeTextCacheEntries')), (true, 0));
  });

  testWidgets(
    'when a glyph changes only its callback, it should reuse the same painting signature',
    (
      tester,
    ) async {
      final harness = ContourNativeTestHarness();
      final first = TapGestureRecognizer()..onTap = () {};
      final second = TapGestureRecognizer()..onTap = () {};
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await harness.mount(
        tester,
        amount: 3,
        child: Text.rich(
          TextSpan(text: 'O', recognizer: first),
          style: const TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFF000000)),
        ),
      );
      final captures = harness.captureCount;
      await harness.mount(
        tester,
        amount: 3,
        child: Text.rich(
          TextSpan(text: 'O', recognizer: second),
          style: const TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFF000000)),
        ),
      );
      expect(harness.captureCount, captures);
    },
  );
  testWidgets('when a custom color changes paragraph serialization, it should avoid sharing that capture', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    await harness.mount(
      tester,
      amount: 3,
      child: const Text(
        'O',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: ContourNativeCustomColor()),
      ),
    );
    await harness.mount(
      tester,
      amount: 3,
      child: const Text(
        'O',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, color: Color(0xFFFFFFFF)),
      ),
    );
    expect(harness.diagnostic('nativeTextActive'), isTrue);
  });

  testWidgets('when font weight changes between hundred-step values, it should keep distinct painting signatures', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    await harness.mount(
      tester,
      amount: 3,
      child: const Text(
        'O',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, fontWeight: FontWeight(450)),
      ),
    );
    final captures = harness.captureCount;
    await harness.mount(
      tester,
      amount: 3,
      child: const Text(
        'O',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, fontWeight: FontWeight.w400),
      ),
    );
    expect(harness.captureCount, greaterThan(captures));
  });
  for (final (name, widget) in <(String, Widget)>[
    (
      'paragraph',
      const Text(
        'O',
        locale: ContourNativeCustomLocale(),
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1),
      ),
    ),
    (
      'text style',
      const Text(
        'O',
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1, locale: ContourNativeCustomLocale()),
      ),
    ),
    (
      'span',
      const Text.rich(
        TextSpan(text: 'O', locale: ContourNativeCustomLocale()),
        style: TextStyle(fontFamily: 'Ahem', fontSize: 24, height: 1),
      ),
    ),
  ]) {
    testWidgets('when a $name locale has custom serialization, it should generate without sharing its capture', (
      tester,
    ) async {
      final harness = ContourNativeTestHarness();
      await harness.mount(tester, amount: 3, child: widget);
      expect((harness.diagnostic('contourReady'), harness.diagnostic('nativeTextCacheEntries')), (true, 0));
    });
  }
}
