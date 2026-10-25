import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'contour_test_harness.dart';

void main() {
  testWidgets('when several backdrops generate together, it should finish every request', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Contour(color: Colors.white, child: Icon(Icons.favorite)),
            Contour(color: Colors.blue, child: Icon(Icons.star)),
            Contour(color: Colors.red, child: Icon(Icons.circle)),
          ],
        ),
      ),
    );
    await ContourTestHarness.settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('when all contours unmount and a new one appears, it should restart processing', (tester) async {
    final first = ContourTestHarness();
    await first.mount(tester, child: const Icon(Icons.favorite, size: 40));
    await tester.pumpWidget(const SizedBox());
    final replacement = ContourTestHarness();
    await replacement.mount(tester, child: const Icon(Icons.star, size: 40));
    final properties = tester.renderObject(find.byKey(replacement.backdropKey)).toDiagnosticsNode().getProperties();
    expect(properties.any((property) => property.name == 'contourReady' && property.value == true), isTrue);
  });

  testWidgets('when disposed during generation, it should release pending work safely', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Contour(color: Colors.white, child: Icon(Icons.favorite)),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(tester.takeException(), isNull);
  });
}
