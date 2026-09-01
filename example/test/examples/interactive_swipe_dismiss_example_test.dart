import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter_example/examples/interactive_swipe_dismiss_example.dart';

void main() {
  testWidgets(
    'when the example is opened, it should show an interactive handle',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: InteractiveSwipeDismissExample()),
        ),
      );

      await tester.tap(find.text('Open dismissible route'));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveSwipeDismissHandle), findsOneWidget);
    },
  );
}
