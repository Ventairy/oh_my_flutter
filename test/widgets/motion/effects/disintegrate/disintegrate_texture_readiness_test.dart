import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'disintegrate_test_harness.dart';

void main() {
  testWidgets('when the prepared texture has not arrived, it should keep the source until disposed', (tester) async {
    final harness = DisintegrateTestHarness(tester, native: true, readinessProbe: true);
    var starts = 0;
    await harness.mount(
      effect: DisintegrateMotionEffect(direction: Offset.zero, onStart: () => starts++),
    );
    await harness.start();
    final beforeDisposal = starts;
    await tester.pumpWidget(const SizedBox.shrink());
    await harness.prepare();
    expect(
      (
        beforeDisposal,
        starts,
        harness.calls.where((call) => call.method == 'dispose').length,
        harness.calls.where((call) => call.method == 'awaitFirstFrame').length,
        tester.takeException(),
      ),
      (0, 0, 1, 0, null),
    );
  });

  testWidgets('when a texture never becomes ready, it should start using the captured pixels', (tester) async {
    final harness = DisintegrateTestHarness(tester, native: true, readinessProbe: true);
    var starts = 0;
    await harness.mount(
      effect: DisintegrateMotionEffect(direction: Offset.zero, onStart: () => starts++),
    );
    await harness.start();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1100)));
    await harness.prepare();
    expect((starts, find.byType(Texture).evaluate().isEmpty, tester.takeException()), (1, true, null));
  });
}
