import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../../benchmark/morph/morph_benchmark_workloads.dart';

void main() {
  group('MorphBenchmarkWorkloads', () {
    for (final behavior in MorphDescendantFlightBehavior.values) {
      testWidgets(
        'when the ${behavior.name} descendant workload is built, '
        'it should configure the requested flight behavior',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MorphBenchmarkWorkloads.descendant(
                  expanded: false,
                  behavior: behavior,
                ),
              ),
            ),
          );

          final descendant = tester.widget<MorphDescendant>(
            find.byType(MorphDescendant),
          );
          expect(
            descendant.flightBehavior,
            behavior,
          );
        },
      );
    }

    testWidgets(
      'when the dense snapshot workload is built, '
      'it should contain twenty-four sibling snapshot descendants',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MorphBenchmarkWorkloads.descendantSnapshotDense(
                expanded: false,
              ),
            ),
          ),
        );

        expect(find.byType(MorphDescendant), findsNWidgets(24));
      },
    );

    testWidgets(
      'when the matched raw Column workload flies, '
      'it should use the resizing hybrid slot',
      (tester) async {
        Size largestSize(Size first, Size second) {
          if (first.width * first.height >= second.width * second.height) {
            return first;
          }
          return second;
        }

        const hybridRenderWidgetName = '_MorphHybridColumnRenderWidget';
        final harnessKey = GlobalKey<_WorkloadHarnessState>();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _WorkloadHarness(
                key: harnessKey,
                builder: ({required expanded}) {
                  return MorphBenchmarkWorkloads.columnMatchedRawResize(
                    expanded: expanded,
                    duration: const Duration(milliseconds: 320),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        harnessKey.currentState!.showDestination();
        await tester.pump();
        await tester.pump();
        final overlay = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_MorphOverlay',
        );
        final hybrid = find.descendant(
          of: overlay,
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == hybridRenderWidgetName,
          ),
        );
        final rawSlots = find.descendant(
          of: hybrid,
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphHybridRawSlot',
          ),
        );
        final initialSizes = rawSlots
            .evaluate()
            .map(
              (element) => tester.getSize(
                find.byElementPredicate(
                  (candidate) => identical(candidate, element),
                ),
              ),
            )
            .toList(growable: false);
        await tester.pump(const Duration(milliseconds: 40));
        final resizedSizes = rawSlots
            .evaluate()
            .map(
              (element) => tester.getSize(
                find.byElementPredicate(
                  (candidate) => identical(candidate, element),
                ),
              ),
            )
            .toList(growable: false);
        final initialRaw = initialSizes.reduce(largestSize);
        final resizedRaw = resizedSizes.reduce(largestSize);

        expect(
          (
            hybrid.evaluate().length,
            rawSlots.evaluate().length,
            find
                .descendant(
                  of: overlay,
                  matching: find.byKey(
                    const ValueKey<String>('matched-resizing-raw-child'),
                  ),
                )
                .evaluate()
                .length,
            resizedRaw.width > initialRaw.width,
            resizedRaw.height > initialRaw.height,
            tester.takeException(),
          ),
          (1, 1, 1, true, true, null),
        );
      },
    );

    testWidgets(
      'when the nested watch workload is built, '
      'it should configure the child and parent timing contract',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MorphBenchmarkWorkloads.nestedWatchHold(
                expanded: false,
              ),
            ),
          ),
        );
        final morphs = tester
            .widgetList<Morph>(
              find.byWidgetPredicate(
                (widget) => widget is Morph,
              ),
            )
            .toList(growable: false);
        final child = morphs.singleWhere(
          (morph) => morph.tag == 'benchmark-nested-watched-text',
        );
        final parent = morphs.singleWhere(
          (morph) => morph.tag == 'benchmark-nested-watch-parent',
        );
        final targetMotion = tester.widget<TweenAnimationBuilder<double>>(
          find.byKey(const ValueKey<String>('nested-watch-motion')),
        );

        expect(
          (
            child.watchDestination,
            child.duration,
            parent.duration,
            targetMotion.duration,
          ),
          (
            true,
            const Duration(milliseconds: 160),
            const Duration(milliseconds: 640),
            const Duration(milliseconds: 640),
          ),
        );
      },
    );

    testWidgets(
      'when the watched child has finished, '
      'it should remain held while its target continues moving',
      (tester) async {
        final harnessKey = GlobalKey<_WorkloadHarnessState>();
        var parentEnded = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _WorkloadHarness(
                key: harnessKey,
                builder: ({required expanded}) {
                  return MorphBenchmarkWorkloads.nestedWatchHold(
                    expanded: expanded,
                    onEnd: () => parentEnded = true,
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        harnessKey.currentState!.showDestination();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final overlay = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_MorphOverlay',
        );
        final heldChildFlights = find.descendant(
          of: overlay,
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphTextFlight',
          ),
        );
        final destination = find.byKey(
          const ValueKey<String>(
            'benchmark-nested_watch_hold-nested-watch-parent-destination',
          ),
          skipOffstage: false,
        );
        final target = find.descendant(
          of: destination,
          matching: find.byKey(
            const ValueKey<String>('nested-watch-target-geometry'),
            skipOffstage: false,
          ),
          skipOffstage: false,
        );
        final heldRect = tester.getRect(target);
        await tester.pump(const Duration(milliseconds: 100));
        final movedRect = tester.getRect(target);

        expect(
          (
            heldChildFlights.evaluate().length,
            movedRect != heldRect,
            parentEnded,
            tester.takeException(),
          ),
          (1, true, false, null),
        );
      },
    );
  });
}

class _WorkloadHarness extends StatefulWidget {
  const _WorkloadHarness({
    required this.builder,
    super.key,
  });

  final Widget Function({required bool expanded}) builder;

  @override
  State<_WorkloadHarness> createState() => _WorkloadHarnessState();
}

class _WorkloadHarnessState extends State<_WorkloadHarness> {
  bool _expanded = false;

  void showDestination() {
    setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(expanded: _expanded);
  }
}
