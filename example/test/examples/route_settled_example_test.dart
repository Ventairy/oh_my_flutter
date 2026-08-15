import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/route_settled_example.dart';

void main() {
  testWidgets(
    'when the RouteSettled example builds on a settled route, '
    'it should show its child',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RouteSettledExample())),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('This appears after route motion settles.'),
        findsOneWidget,
      );
    },
  );
}
