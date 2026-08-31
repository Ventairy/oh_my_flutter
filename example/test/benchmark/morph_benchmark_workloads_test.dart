import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../../benchmark/morph/morph_benchmark_snapshot_paint_probe.dart';
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
      'when the dense snapshot workload watches its destination, '
      'it should enable destination watching',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MorphBenchmarkWorkloads.descendantSnapshotDense(
                expanded: false,
                watchDestination: true,
              ),
            ),
          ),
        );

        expect(
          tester.widget<Morph>(find.byType(Morph)).watchDestination,
          isTrue,
        );
      },
    );

    testWidgets(
      'when the dynamic dense snapshot workload is built, '
      'it should track one dirty descendant and preserve one control',
      (tester) async {
        final dirtyProbe = MorphBenchmarkSnapshotPaintProbe();
        final unchangedProbe = MorphBenchmarkSnapshotPaintProbe();
        addTearDown(dirtyProbe.dispose);
        addTearDown(unchangedProbe.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MorphBenchmarkWorkloads.descendantSnapshotDense(
                expanded: false,
                watchDestination: true,
                dynamicWatchedSnapshot: true,
                surfaceChanges: dirtyProbe.changes,
                dirtySnapshotPainter: dirtyProbe,
                unchangedSnapshotPainter: unchangedProbe,
              ),
            ),
          ),
        );

        final descendants = tester.widgetList<MorphDescendant>(
          find.byType(MorphDescendant),
        );
        final dirtyDescendant = find.byKey(const ValueKey<int>(0));
        final nestedRepaintBoundaries = find.descendant(
          of: dirtyDescendant,
          matching: find.byType(RepaintBoundary),
        );
        final surface = find.byKey(
          const ValueKey<String>(
            'benchmark-watch_snapshot_dynamic-surface-source',
          ),
        );
        final initialRect = tester.getRect(surface);

        dirtyProbe.requestMutationBatch();
        await tester.pump();
        final changedRect = tester.getRect(surface);

        expect(
          (
            tester.widget<Morph>(find.byType(Morph)).watchDestination,
            descendants.length,
            nestedRepaintBoundaries.evaluate().length,
            changedRect != initialRect,
            dirtyProbe.requestedGeneration,
          ),
          (true, 24, 0, true, 3),
        );
      },
    );

    testWidgets(
      'when the geometry-only watched snapshot workload changes, '
      'it should move the surface without repainting descendant pixels',
      (tester) async {
        final geometryChanges = ValueNotifier<int>(0);
        final dirtyProbe = MorphBenchmarkSnapshotPaintProbe();
        final unchangedProbe = MorphBenchmarkSnapshotPaintProbe();
        addTearDown(geometryChanges.dispose);
        addTearDown(dirtyProbe.dispose);
        addTearDown(unchangedProbe.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MorphBenchmarkWorkloads.descendantSnapshotDense(
                expanded: false,
                watchDestination: true,
                geometryOnlyWatchedSnapshot: true,
                surfaceChanges: geometryChanges,
                dirtySnapshotPainter: dirtyProbe,
                unchangedSnapshotPainter: unchangedProbe,
              ),
            ),
          ),
        );

        final descendants = tester.widgetList<MorphDescendant>(
          find.byType(MorphDescendant),
        );
        final surface = find.byKey(
          const ValueKey<String>(
            'benchmark-watch_snapshot_geometry_only-surface-source',
          ),
        );
        final initialRect = tester.getRect(surface);
        final dirtyPaintStart = dirtyProbe.paintEventCount;
        final unchangedPaintStart = unchangedProbe.paintEventCount;
        geometryChanges.value = 3;
        await tester.pump();
        final changedRect = tester.getRect(surface);

        expect(
          (
            descendants.length,
            changedRect != initialRect,
            dirtyProbe.paintEventCount - dirtyPaintStart,
            unchangedProbe.paintEventCount - unchangedPaintStart,
          ),
          (24, true, 0, 0),
        );
      },
    );

    testWidgets(
      'when the full-surface watched snapshot workload changes, '
      'it should resize one automatically tracked near-full descendant only',
      (tester) async {
        final dirtyProbe = MorphBenchmarkSnapshotPaintProbe();
        final unchangedProbe = MorphBenchmarkSnapshotPaintProbe();
        addTearDown(dirtyProbe.dispose);
        addTearDown(unchangedProbe.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MorphBenchmarkWorkloads.watchedSnapshotFullSurface(
                expanded: false,
                surfaceChanges: dirtyProbe.changes,
                dirtySnapshotPainter: dirtyProbe,
                unchangedSnapshotPainter: unchangedProbe,
              ),
            ),
          ),
        );

        final changingDescendant = find.byKey(
          const ValueKey<String>('full-surface-dirty'),
        );
        final initialSize = tester.getSize(changingDescendant);
        dirtyProbe.requestMutationBatch(mutations: 1);
        await tester.pump();
        final changedSize = tester.getSize(changingDescendant);

        expect(
          (
            find.byType(MorphDescendant).evaluate().length,
            changingDescendant.evaluate().length,
            changedSize != initialSize,
          ),
          (2, 1, true),
        );
      },
    );

    testWidgets(
      'when the nested fallback snapshot workload is built, '
      'it should independently repaint one nested boundary',
      (tester) async {
        final dirtyProbe = MorphBenchmarkSnapshotPaintProbe();
        final unchangedProbe = MorphBenchmarkSnapshotPaintProbe();
        addTearDown(dirtyProbe.dispose);
        addTearDown(unchangedProbe.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MorphBenchmarkWorkloads.descendantSnapshotDense(
                expanded: false,
                watchDestination: true,
                nestedSnapshotFallback: true,
                dirtySnapshotPainter: dirtyProbe,
                unchangedSnapshotPainter: unchangedProbe,
              ),
            ),
          ),
        );

        final descendantFinder = find.byType(MorphDescendant);
        final widgetList = tester.widgetList<MorphDescendant>(descendantFinder);
        final descendants = List<MorphDescendant>.of(
          widgetList,
          growable: false,
        );
        bool hasNestedBoundary(MorphDescendant descendant) {
          return descendant.child is RepaintBoundary;
        }

        final nestedBoundaryCount = descendants.where(hasNestedBoundary).length;
        final dirtyPaintStart = dirtyProbe.paintEventCount;
        final unchangedPaintStart = unchangedProbe.paintEventCount;
        dirtyProbe.requestMutationBatch(mutations: 1);
        await tester.pump();

        expect(
          (
            descendants.length,
            nestedBoundaryCount,
            dirtyProbe.paintEventCount - dirtyPaintStart,
            unchangedProbe.paintEventCount - unchangedPaintStart,
            dirtyProbe.lastPaintedGeneration,
          ),
          (24, 24, 1, 0, 1),
        );
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
