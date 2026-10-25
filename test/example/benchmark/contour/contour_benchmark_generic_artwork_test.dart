import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../example/benchmark/contour/contour_benchmark_generic_artwork.dart';

void main() {
  testWidgets('when generic artwork changes, it should keep every variant within its benchmark cell', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: ContourBenchmarkGenericArtwork(variant: 39)),
      ),
    );
    expect(tester.getSize(find.byType(ContourBenchmarkGenericArtwork)), const Size(32, 30));
  });
}
