// dart format width=80
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oh_my_flutter_example/examples/snap_list_example.dart';

void main() {
  testWidgets(
    'when extra pages are enabled, it should show the example page and its shared coordinates',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox(width: 400, child: SnapListExample())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show extra pages'));
      await tester.pumpAndSettle();
      for (var step = 0; step < 2; step++) {
        await tester.tap(find.text('Next card'));
        await tester.pumpAndSettle();
      }
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();
      expect(
        (
          find.text('Extra page after card 2').hitTestable().evaluate().length,
          find.text('Index 1 · Position 1.00').evaluate().length,
        ),
        (1, 1),
      );
    },
  );
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
