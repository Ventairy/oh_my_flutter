import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../../benchmark/morph/morph_benchmark_live_caret_painter.dart';
import '../../benchmark/morph/morph_benchmark_multi_foreground_workload.dart';

void main() {
  group('MorphBenchmarkMultiForegroundWorkload', () {
    testWidgets(
      'when the default-size static workload builds, '
      'it should create sixteen foregrounds',
      (tester) async {
        final painter = MorphBenchmarkLiveCaretPainter(
          const AlwaysStoppedAnimation<double>(0),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MorphBenchmarkMultiForegroundWorkload(
                count: 16,
                mixed: false,
                livePainter: painter,
              ),
            ),
          ),
        );

        expect(find.byType(MorphSibling), findsNWidgets(16));
      },
    );

    testWidgets(
      'when the mixed workload builds, '
      'it should create one paint-only live control',
      (tester) async {
        final painter = MorphBenchmarkLiveCaretPainter(
          const AlwaysStoppedAnimation<double>(0),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MorphBenchmarkMultiForegroundWorkload(
                count: 16,
                mixed: true,
                livePainter: painter,
              ),
            ),
          ),
        );

        final livePaint = find.byWidgetPredicate((widget) {
          if (widget is! CustomPaint) return false;
          return identical(widget.foregroundPainter, painter);
        });

        expect(livePaint, findsOneWidget);
      },
    );
  });
}
