import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_shadow_pool_test_harness.dart';

/// Exercises shared atlas images with independently configurable source owners.
class ContourShadowAtlasTestHarness extends ContourShadowPoolTestHarness {
  /// Changes amounts over enough frames to enable the animated shadow atlas.
  Future<void> animate(
    WidgetTester tester, {
    int count = 2,
    double base = 0,
    List<Shadow> shadows = const [Shadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
    List<Shadow> Function(int)? shadowsFor,
    Widget Function(int)? childFor,
  }) async {
    await mount(tester, count: count, amount: base + 1, shadows: shadows, shadowsFor: shadowsFor, childFor: childFor);
    for (final amount in [base + 2, base + 3, base + 4]) {
      await tester.pump(const Duration(milliseconds: 60));
      await mount(
        tester,
        count: count,
        amount: amount,
        shadows: shadows,
        shadowsFor: shadowsFor,
        childFor: childFor,
        settle: false,
      );
    }
    await settle(tester);
  }

  /// Waits until every mounted owner completes its current atlas request.
  Future<void> settle(WidgetTester tester) async {
    for (var attempt = 0; attempt < 600; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 1));
      final generating = [
        for (var index = 0; index < keys.length; index++)
          if (keys[index].currentContext != null) property('generating', index),
      ].contains(true);
      if (!generating && !tester.binding.hasScheduledFrame) return;
    }
    throw StateError('Contour atlas did not finish generating.');
  }
}
