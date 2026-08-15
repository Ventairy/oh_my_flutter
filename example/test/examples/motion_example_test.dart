import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/motion_example.dart';

void main() {
  testWidgets(
    'when the Motion example finishes its one-shot effect, '
    'it should report completion',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MotionExample())),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('Motion completed'), findsOneWidget);
    },
  );

  testWidgets(
    'when the replay action is tapped, it should start the Motion again',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MotionExample())),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Play motion again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('Motion started'), findsOneWidget);
    },
  );
}
