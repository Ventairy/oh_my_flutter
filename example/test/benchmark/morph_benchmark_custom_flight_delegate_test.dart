import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../../benchmark/morph/morph_benchmark_custom_flight_delegate.dart';

void main() {
  testWidgets(
    'when the custom benchmark endpoint changes, '
    'it should paint the interpolated flight color',
    (tester) async {
      var destination = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Center(
                child: SizedBox(
                  width: destination ? 200 : 100,
                  height: destination ? 140 : 70,
                  child: Morph(
                    tag: 'custom-benchmark-test',
                    duration: const Duration(milliseconds: 100),
                    flightDelegate: const BenchmarkCustomFlightDelegate(),
                    child: ColoredBox(
                      color: destination ? Colors.blue : Colors.red,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final coloredBoxes = tester.widgetList<ColoredBox>(
        find.byType(ColoredBox),
      );
      final paintedColors = coloredBoxes.map((box) => box.color);
      expect(
        paintedColors,
        contains(Color.lerp(Colors.red, Colors.blue, 0.5)),
      );
      await tester.pumpAndSettle();
    },
  );
}
