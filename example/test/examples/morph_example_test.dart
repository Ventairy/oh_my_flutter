import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/morph_example.dart';

void main() {
  testWidgets(
    'when the Morph actions are used, it should transfer on screen and '
    'across a route',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MorphExample())),
      );

      await tester.tap(find.text('Transfer Morph ownership'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final sameScreenDestinationVisible = find
          .text('Morph works across routes and within one screen.')
          .evaluate()
          .isNotEmpty;
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open route Morph'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      expect(
        (
          sameScreenDestinationVisible,
          find.text('Route destination').evaluate().isNotEmpty,
        ),
        (true, true),
      );
    },
  );
}
