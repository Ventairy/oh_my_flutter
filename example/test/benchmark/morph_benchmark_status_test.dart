import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/morph/morph_benchmark_status.dart';

void main() {
  group('MorphBenchmarkStatus', () {
    testWidgets(
      'when timing is active, it should not build status text',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Stack(
              children: [
                MorphBenchmarkStatus(
                  complete: false,
                  status: 'Benchmarking text…',
                ),
              ],
            ),
          ),
        );

        expect(find.byType(Text), findsNothing);
      },
    );

    testWidgets(
      'when timing has completed, it should display the result',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Stack(
              children: [
                MorphBenchmarkStatus(
                  complete: true,
                  status: 'Benchmark passed.',
                ),
              ],
            ),
          ),
        );

        expect(find.text('Benchmark passed.'), findsOneWidget);
      },
    );
  });
}
