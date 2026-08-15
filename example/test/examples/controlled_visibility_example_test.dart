import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/controlled_visibility_example.dart';

void main() {
  testWidgets(
    'when the visibility button is tapped, it should expose the hide action',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ControlledVisibilityExample()),
        ),
      );
      await tester.tap(find.text('Show details'));
      await tester.pump();

      expect(find.text('Hide details'), findsOneWidget);
    },
  );
}
