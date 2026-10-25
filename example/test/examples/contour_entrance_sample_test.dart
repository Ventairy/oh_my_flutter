import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter_example/examples/contour_entrance_sample.dart';

import 'contour_entrance_test_painter.dart';

void main() {
  Widget scene({bool reducedMotion = false}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: const Scaffold(
        body: ContourEntranceSample(
          waitUntilReady: true,
          delay: Duration(milliseconds: 200),
          pop: true,
          child: SizedBox.square(
            dimension: 24,
            child: DecoratedBox(decoration: BoxDecoration(color: Colors.red)),
          ),
        ),
      ),
    ),
  );

  testWidgets('when awaiting the entrance deadline, it should prepare while still transparent', (tester) async {
    await tester.pumpWidget(scene());
    await tester.pump();
    expect(
      (
        tester.widget<Contour>(find.byType(Contour)).controller!.isReady,
        tester.widget<FadeTransition>(find.byType(FadeTransition).last).opacity.value,
      ),
      (true, 0),
    );
  });

  testWidgets('when the prepared entrance reaches its deadline, it should run the full 300 ms effect', (tester) async {
    await tester.pumpWidget(scene());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition).last).opacity.value, closeTo(.5, .01));
  });

  testWidgets('when motion is disabled, it should skip the stagger and entrance animation', (tester) async {
    await tester.pumpWidget(scene(reducedMotion: true));
    expect(tester.widget<FadeTransition>(find.byType(FadeTransition).last).opacity.value, 1);
  });

  testWidgets('when disposed before its deadline, it should cancel the pending entrance', (tester) async {
    await tester.pumpWidget(scene());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('when preparation outlasts the stagger, it should preserve the full animation after readiness', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ContourEntranceSample(
            waitUntilReady: true,
            delay: Duration(milliseconds: 200),
            pop: true,
            child: SizedBox.square(dimension: 24, child: CustomPaint(painter: ContourEntranceTestPainter())),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final controller = tester.widget<Contour>(find.byType(Contour)).controller!;
    final readyAtDeadline = controller.isReady;
    final opacityAtDeadline = tester.widget<FadeTransition>(find.byType(FadeTransition).last).opacity.value;
    for (var attempt = 0; attempt < 200 && !controller.isReady; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      [
        readyAtDeadline,
        opacityAtDeadline,
        controller.isReady,
        tester.widget<FadeTransition>(find.byType(FadeTransition).last).opacity.value,
      ],
      [false, 0, true, closeTo(.5, .01)],
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  });
}
