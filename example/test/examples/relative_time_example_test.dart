import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/relative_time_example.dart';

void main() {
  testWidgets(
    'when the relative time example builds, '
    'it should show the deterministic label',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RelativeTimeExample())),
      );

      expect(find.text('5 minutes ago'), findsOneWidget);
    },
  );
}
