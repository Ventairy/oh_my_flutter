import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';

import 'contour_ordinary_test_painter.dart';
import 'contour_test_harness.dart';

void main() {
  testWidgets('when ordinary custom artwork is wrapped, it should generate its contour automatically', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 4,
      child: CustomPaint(size: const Size(60, 50), painter: ContourOrdinaryTestPainter()),
    );
    final properties = harness.backdropKey.currentContext!.findRenderObject()!.toDiagnosticsNode().getProperties();
    Object? value(String name) => properties.firstWhere((property) => property.name == name).value;
    final actual = (value('declaredPathActive'), harness.captureCount > 0, value('firstPresentationHasContour'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(ContourProcessorTestHarness.waitForStop);
    expect(actual, (false, true, true));
  });
}
