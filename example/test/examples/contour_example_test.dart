import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/contour_example.dart';

void main() {
  testWidgets('when changing the label, it should update the live text immediately', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ContourExample())),
      ),
    );
    await tester.tap(find.text('Change text'));
    await tester.pump();
    expect(find.text('Olá, mundo!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  });
}
