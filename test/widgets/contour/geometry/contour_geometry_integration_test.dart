import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;

import 'contour_geometry_integration_harness.dart';

void main() {
  // Exercise canonical geometry and shadow sharing on the sampled fallback.
  setUp(() => ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared);
  tearDown(() => ContourCompositeSource.testOverride = null);

  testWidgets('when forty generic children repeat two shapes, it should reuse canonical source paths', (tester) async {
    final harness = ContourGeometryIntegrationHarness();
    await harness.mount(tester, shadows: false);
    expect(harness.unique('geometryIdentity'), 2);
  });

  testWidgets('when composed widget artwork is captured, it should keep the generic native stroke path', (
    tester,
  ) async {
    final harness = ContourGeometryIntegrationHarness();
    await harness.mount(tester, shadows: false);
    expect(List.generate(40, (i) => harness.property(i, 'nativeTextActive')).every((value) => value == false), isTrue);
  });

  testWidgets('when forty generic children are distinct, it should retain forty independent source paths', (
    tester,
  ) async {
    final harness = ContourGeometryIntegrationHarness();
    await harness.mount(tester, unique: true, shadows: false);
    expect(harness.unique('geometryIdentity'), 40);
  });

  testWidgets('when repeated generic artwork has shadows, it should reuse only equivalent shadow images', (
    tester,
  ) async {
    final harness = ContourGeometryIntegrationHarness();
    await harness.mount(tester);
    expect(harness.unique('shadowResourceId'), 2);
  });
}
