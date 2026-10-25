import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_test_harness.dart';
import 'contour_test_painter.dart';

void main() {
  testWidgets('when tracing produces ordinary geometry, it should deliver a successful backing without a retry', (
    tester,
  ) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 2,
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter(circle: true)),
    );
    final properties = tester.renderObject(find.byKey(harness.backdropKey)).toDiagnosticsNode().getProperties();
    expect(
      [
        properties.singleWhere((property) => property.name == 'contourReady').value,
        properties.singleWhere((property) => property.name == 'geometryCapacityExceededCount').value,
      ],
      [true, 0],
    );
  });

  testWidgets('when tracing produces no visible edges, it should accept the empty result without a capacity retry', (
    tester,
  ) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 2,
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter(empty: true)),
    );
    final properties = tester.renderObject(find.byKey(harness.backdropKey)).toDiagnosticsNode().getProperties();
    expect(
      [
        properties.singleWhere((property) => property.name == 'contourReady').value,
        properties.singleWhere((property) => property.name == 'geometryCapacityExceededCount').value,
      ],
      [true, 0],
    );
  });
}
