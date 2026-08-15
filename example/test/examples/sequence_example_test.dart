import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/sequence_example.dart';

void main() {
  testWidgets(
    'when the next action is tapped, it should advance the Sequence',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SequenceExample())),
      );
      await tester.tap(find.byTooltip('Next step'));
      await tester.pumpAndSettle();

      expect(
        (
          find.text('Sequence step two').evaluate().isNotEmpty,
          find.text('Step 2 of 3').evaluate().isNotEmpty,
        ),
        (true, true),
      );
    },
  );
}
