import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_box_gaussian_test_fixture.dart';

void main() {
  testWidgets('when an earlier mesh support override is disposed, it should preserve the newer contour capability', (
    tester,
  ) async {
    final first = ContourBoxGaussianTestFixture();
    await tester.pumpWidget(first.scene());
    final firstValues = first.values;
    await tester.pumpWidget(const SizedBox.shrink());
    final second = ContourBoxGaussianTestFixture(supported: false);
    first.dispose();
    await tester.pumpWidget(second.scene());
    final secondValues = second.values;
    expect(
      (
        firstValues['boxGaussianMeshPaintCount'],
        firstValues['firstPresentationHasContour'],
        secondValues['boxGaussianMeshPaintCount'],
        secondValues['firstPresentationHasContour'],
        (secondValues['boxGaussianNativePaintCount']! as int) > 0,
      ),
      (
        1,
        true,
        0,
        true,
        true,
      ),
    );
    second.dispose();
  });
}
