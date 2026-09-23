import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter_example/examples/morph_local_example.dart';

void main() {
  testWidgets('when details mount, it should show the details appearance', (tester) async {
    final observer = MorphNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: const Scaffold(body: MorphLocalExample()),
      ),
    );
    await tester.tap(find.text('Mount details'));
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
  });

  testWidgets('when details are removed, it should restore the card appearance', (tester) async {
    final observer = MorphNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: const Scaffold(body: MorphLocalExample()),
      ),
    );
    await tester.tap(find.text('Mount details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove details'));
    await tester.pumpAndSettle();

    expect(find.text('A compact card').hitTestable(), findsOneWidget);
  });
}
