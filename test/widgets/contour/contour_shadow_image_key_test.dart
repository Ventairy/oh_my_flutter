import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_native_custom_color.dart';
import 'contour_shadow_custom_offset.dart';
import 'contour_shadow_custom_shadow.dart';
import 'contour_shadow_pool_test_harness.dart';
import 'contour_test_painter.dart';

void main() {
  testWidgets('when equivalent shadow values come from separate lists, it should share one image', (tester) async {
    final harness = ContourShadowPoolTestHarness();
    await harness.mount(
      tester,
      shadowsFor: (_) => [const Shadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
    );
    expect(
      (
        harness.property('nativeTextActive'),
        harness.resourceIds(20).toSet().length,
        harness.resourceIds(20).contains(0),
      ),
      (true, 1, false),
    );
  });

  testWidgets('when amounts differ for the same shape, it should retain separate shadow images', (tester) async {
    final harness = ContourShadowPoolTestHarness();
    await harness.mount(tester, amountFor: (index) => index < 10 ? 3 : 6);
    expect(
      (
        harness.property('nativeTextActive'),
        harness.resourceIds(20).toSet().length,
        harness.resourceIds(20).contains(0),
      ),
      (true, 2, false),
    );
  });

  testWidgets('when shadow colors differ for the same shape, it should retain separate shadow images', (tester) async {
    final harness = ContourShadowPoolTestHarness();
    await harness.mount(
      tester,
      shadowsFor: (index) => [
        Shadow(
          blurRadius: 4,
          color: index < 10 ? const Color(0x33FF0000) : const Color(0x330000FF),
          offset: const Offset(0, 2),
        ),
      ],
    );
    expect(
      (
        harness.property('nativeTextActive'),
        harness.resourceIds(20).toSet().length,
        harness.resourceIds(20).contains(0),
      ),
      (true, 2, false),
    );
  });

  testWidgets('when shadow offsets differ for the same shape, it should retain separate shadow images', (tester) async {
    final harness = ContourShadowPoolTestHarness();
    await harness.mount(
      tester,
      shadowsFor: (index) => [
        Shadow(color: const Color(0x33000000), blurRadius: 4, offset: Offset(0, index < 10 ? 2 : 4)),
      ],
    );
    expect(
      (
        harness.property('nativeTextActive'),
        harness.resourceIds(20).toSet().length,
        harness.resourceIds(20).contains(0),
      ),
      (true, 2, false),
    );
  });

  testWidgets('when a custom shadow overrides paint values, it should keep each image owned separately', (
    tester,
  ) async {
    final harness = ContourShadowPoolTestHarness();
    await harness.mount(
      tester,
      shadows: const [ContourShadowCustomShadow(4)],
      childFor: (_) => const CustomPaint(size: Size.square(20), painter: ContourTestPainter(circle: true)),
    );
    expect(
      (
        harness.property('nativeTextActive'),
        harness.resourceIds(20).toSet().length,
        harness.resourceIds(20).contains(0),
      ),
      (false, 20, false),
    );
  });

  testWidgets('when a shadow uses a custom color, it should keep each image owned separately', (tester) async {
    final harness = ContourShadowPoolTestHarness();
    await harness.mount(
      tester,
      shadows: const [Shadow(blurRadius: 4, color: ContourNativeCustomColor(), offset: Offset(0, 2))],
      childFor: (_) => const CustomPaint(size: Size.square(20), painter: ContourTestPainter(circle: true)),
    );
    expect(
      (
        harness.property('nativeTextActive'),
        harness.resourceIds(20).toSet().length,
        harness.resourceIds(20).contains(0),
      ),
      (false, 20, false),
    );
  });

  testWidgets('when a shadow uses a custom offset, it should keep each image owned separately', (tester) async {
    final harness = ContourShadowPoolTestHarness();
    await harness.mount(
      tester,
      shadows: const [Shadow(color: Color(0x33000000), blurRadius: 4, offset: ContourShadowCustomOffset())],
    );
    expect(
      (
        harness.property('nativeTextActive'),
        harness.resourceIds(20).toSet().length,
        harness.resourceIds(20).contains(0),
      ),
      (true, 20, false),
    );
  });
}
