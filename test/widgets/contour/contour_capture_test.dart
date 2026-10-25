import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_test_harness.dart';

void main() {
  testWidgets('when wrapping an icon, it should leave the icon semantics intact', (tester) async {
    final semantics = tester.ensureSemantics();
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      child: const Icon(Icons.favorite, size: 40, color: Colors.red, semanticLabel: 'Favorite'),
    );
    expect(find.bySemanticsLabel('Favorite'), findsOneWidget);
    semantics.dispose();
  });
}
