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
  testWidgets(
    'when moving forward, it should fade the incoming card with scrolling',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox(width: 400, child: SnapListExample())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next card'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 65));
      final opacity = tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text('Card 2'),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();
      expect(opacity, allOf(greaterThan(0), lessThan(1)));
    },
  );

  testWidgets('when moving backward, it should keep the incoming card opaque', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(width: 400, child: SnapListExample())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Previous card'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 65));
    final opacity = tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.text('Card 1'),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity
        .value;
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();
    expect(opacity, 1);
  });
}
