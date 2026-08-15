import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/marquee_example.dart';

void main() {
  testWidgets(
    'when the Marquee example builds, it should display every source item',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MarqueeExample())),
      );

      expect(
        (
          find.text('Portable').evaluate().isNotEmpty,
          find.text('Strongly typed').evaluate().isNotEmpty,
          find.text('Low allocation').evaluate().isNotEmpty,
        ),
        (true, true, true),
      );
    },
  );
}
