import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show ThemeData;

import 'configured_disintegrate_effect.dart';
import 'disintegrate_test_harness.dart';
import 'held_transform_disintegrate_effect.dart';

void main() {
  for (final overlay in [false, true]) {
    testWidgets(
      'when a held ${overlay ? 'overlay' : 'replacement'} effect transforms its source, it should paint that initial transform',
      (tester) async {
        final harness = DisintegrateTestHarness(tester);
        await harness.mount(
          overlay: overlay,
          effect: const HeldTransformDisintegrateEffect(),
          child: const SizedBox(key: ValueKey('source'), width: 120, height: 80),
        );
        expect(tester.getRect(find.byKey(const ValueKey('source'))).width, 60);
      },
    );
  }
  testWidgets('when an empty capture is skipped, it should keep the live source visible when it gains a size', (
    tester,
  ) async {
    final harness = DisintegrateTestHarness(tester);
    final size = ValueNotifier(Size.zero);
    addTearDown(size.dispose);
    await harness.mount(
      effect: const ConfiguredDisintegrateEffect(progress: 0.5),
      child: ValueListenableBuilder<Size>(
        valueListenable: size,
        builder: (context, value, child) => SizedBox.fromSize(size: value, child: child),
        child: ColoredBox(color: ThemeData.light().colorScheme.primary),
      ),
    );
    await harness.start();
    size.value = const Size(120, 80);
    await tester.pump();
    final pixels = await harness.pixels();
    expect(pixels[(90 * 240 + 120) * 4 + 3], 255);
  });
}
