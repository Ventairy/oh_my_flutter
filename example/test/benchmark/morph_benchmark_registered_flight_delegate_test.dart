import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../../benchmark/morph/morph_benchmark_registered_flight_delegate.dart';
import '../../benchmark/morph/morph_benchmark_workloads.dart';

void main() {
  testWidgets(
    'when registered dense content transitions, '
    'it should display all twenty-four captured descendants',
    (tester) async {
      final morphObserver = MorphNavigatorObserver();
      final target = MorphTarget(tag: 'benchmark');
      final expanded = ValueNotifier(false);
      addTearDown(expanded.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [morphObserver],
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: expanded,
              builder: (context, value, child) {
                return MorphBenchmarkWorkloads.descendantSnapshotDense(
                  target: target,
                  expanded: value,
                  registeredContent: true,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expanded.value = true;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(
        find.byWidgetPredicate(
          (widget) {
            if (widget is! CustomPaint) return false;
            final painterType = widget.painter.runtimeType.toString();
            return painterType == '_MorphContentSnapshotPainter';
          },
        ),
        findsNWidgets(24),
      );
      await tester.pumpAndSettle();
    },
  );

  test(
    'when surface values interpolate across the content switch, '
    'it should select the destination '
    'while interpolating the surrounding values',
    () {
      const sourceChild = Text('source');
      const destinationChild = Text('destination');
      const delegate = RegisteredDelegate();
      final properties = delegate.lerpProperties(
        (
          decoration: const BoxDecoration(color: Colors.black),
          padding: const EdgeInsets.all(8),
          child: sourceChild,
        ),
        (
          decoration: const BoxDecoration(color: Colors.white),
          padding: const EdgeInsets.all(16),
          child: destinationChild,
        ),
        0.75,
      );

      expect(
        (
          identical(properties.child, destinationChild),
          properties.padding,
          (properties.decoration as BoxDecoration).color,
        ),
        (
          true,
          const EdgeInsets.all(14),
          Color.lerp(Colors.black, Colors.white, 0.75),
        ),
      );
    },
  );
}
