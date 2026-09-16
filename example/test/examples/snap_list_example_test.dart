// dart format width=80
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/snap_list_example.dart';

void main() {
  testWidgets(
    'when next card is pressed, it should navigate and request more content',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox(width: 400, child: SnapListExample())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next card'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();
      expect(find.text('2 / 6'), findsOneWidget);
    },
  );
}
