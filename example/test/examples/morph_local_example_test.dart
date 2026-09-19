import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter_example/examples/morph_local_example.dart';

void main() {
  testWidgets('when details mount, it should show their external header', (tester) async {
    final observer = MorphNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: const Scaffold(body: MorphLocalExample()),
      ),
    );
    await tester.tap(find.text('Mount details'));
    await tester.pumpAndSettle();

    final header = tester.widget<FadeTransition>(
      find.descendant(
        of: find.ancestor(of: find.text('Details header'), matching: find.byType(MorphSibling)),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(header.opacity.value, 1);
  });

  testWidgets('when details are removed, it should restore the card header', (tester) async {
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

    final header = tester.widget<FadeTransition>(
      find.descendant(
        of: find.ancestor(of: find.text('Card header'), matching: find.byType(MorphSibling)),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(header.opacity.value, 1);
  });
}
