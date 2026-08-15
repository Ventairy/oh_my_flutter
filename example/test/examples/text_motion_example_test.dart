import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/text_motion_example.dart';

void main() {
  testWidgets(
    'when the TextMotion example builds, it should display the complete text',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TextMotionExample())),
      );
      final completeText = find.bySemanticsLabel('Motion for every letter');
      final completeTextCount = completeText.evaluate().length;
      semantics.dispose();

      expect(completeTextCount, 1);
    },
  );
}
