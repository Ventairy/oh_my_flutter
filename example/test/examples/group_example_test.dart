import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/group_example.dart';

void main() {
  testWidgets('when capture is pressed, it should display a combined preview', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: GroupExample())));
    await tester.runAsync(() async {
      await tester.tap(find.text('Capture group'));
      await tester.pumpAndSettle();
    });
    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsOneWidget);
  });
}
