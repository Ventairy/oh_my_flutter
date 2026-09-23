import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../../benchmark/morph/morph_benchmark_group_flight_delegate.dart';
import '../../benchmark/morph/morph_benchmark_snapshot_paint_probe.dart';
import '../../benchmark/morph/morph_benchmark_workloads.dart';

void main() {
  group('MorphBenchmarkWorkloads', () {
    testWidgets('when the full-surface group footer changes, '
        'it should capture each requested generation once', (tester) async {
      final morphObserver = MorphNavigatorObserver();
      final target = MorphTarget(tag: 'benchmark-group', duration: const Duration(seconds: 1), watchDestination: true);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(360, 752);
      addTearDown(tester.view.reset);
      final expanded = ValueNotifier(false);
      final sourceGroup = GroupLink();
      final destinationGroup = GroupLink();
      final dirty = MorphBenchmarkSnapshotPaintProbe(capturesOnly: true);
      final clean = MorphBenchmarkSnapshotPaintProbe(capturesOnly: true);
      int? dirtyEnd;
      int? cleanEnd;
      addTearDown(expanded.dispose);
      addTearDown(dirty.dispose);
      addTearDown(clean.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [morphObserver],
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: expanded,
              builder: (context, value, child) {
                return MorphBenchmarkWorkloads.watchedGroupKeyboard(
                  target: target,
                  showDestination: value,
                  sourceLink: sourceGroup,
                  destinationLink: destinationGroup,
                  surfaceChanges: dirty.changes,
                  dirtyGroupPainter: dirty,
                  unchangedPainter: clean,
                  sourceDelegate: MorphBenchmarkGroupFlightDelegate(sourceGroup),
                  destinationDelegate: MorphBenchmarkGroupFlightDelegate(destinationGroup),
                  onEnd: () {
                    dirtyEnd ??= dirty.paintEventCount;
                    cleanEnd ??= clean.paintEventCount;
                  },
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
      await tester.pump(const Duration(milliseconds: 100));
      final dirtyStart = dirty.paintEventCount;
      final cleanStart = clean.paintEventCount;
      for (var batch = 0; batch < 12; batch += 1) {
        dirty.requestMutationBatch(mutations: 1);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      expect(
        (
          dirty.measureSince(dirtyStart, lastEvent: dirtyEnd).capturedGenerations.join(','),
          clean.measureSince(cleanStart, lastEvent: cleanEnd).capturePaints,
        ),
        ('1,2,3,4,5,6,7,8,9,10,11,12', 0),
      );
      expect(dirty.measureSince(dirtyEnd!).capturePaints, 0);

      final liveRefreshStart = dirty.paintEventCount;
      dirty.requestMutationBatch(mutations: 1);
      await tester.pump();
      await tester.pump();
      expect(dirty.measureSince(liveRefreshStart).capturedGenerations, <int>[13]);
      final unchangedStart = dirty.paintEventCount;
      await tester.pump();
      await tester.pump();
      expect(dirty.measureSince(unchangedStart).capturePaints, 0);
    });

    testWidgets('when the stationary group A/B pair is built, '
        'it should only change destination watching', (tester) async {
      final morphObserver = MorphNavigatorObserver();
      final sourceGroup = GroupLink();
      final destinationGroup = GroupLink();
      final dirty = MorphBenchmarkSnapshotPaintProbe(capturesOnly: true);
      final clean = MorphBenchmarkSnapshotPaintProbe(capturesOnly: true);
      addTearDown(dirty.dispose);
      addTearDown(clean.dispose);

      Future<({String geometry, bool watchesDestination})> inspect(MorphTarget target) async {
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [morphObserver],
            home: Scaffold(
              body: MorphBenchmarkWorkloads.stationaryGroup(
                target: target,
                showDestination: false,
                sourceLink: sourceGroup,
                destinationLink: destinationGroup,
                dirtyGroupPainter: dirty,
                unchangedPainter: clean,
                sourceDelegate: MorphBenchmarkGroupFlightDelegate(sourceGroup),
                destinationDelegate: MorphBenchmarkGroupFlightDelegate(destinationGroup),
              ),
            ),
          ),
        );
        await tester.pump();

        final surface = find.byKey(const ValueKey<String>('benchmark-watch_group_stationary-surface-source'));
        final surfaceRect = tester.getRect(surface);
        final groupRects = <Rect>[
          for (final element in find.byType(Group).evaluate())
            tester
                .getRect(find.byElementPredicate((candidate) => identical(candidate, element)))
                .shift(-surfaceRect.topLeft),
        ];
        return (
          geometry:
              '${surfaceRect.size}|${groupRects.join('|')}|'
              '${find.byType(Group).evaluate().length}|'
              '${find.byType(ValueListenableBuilder<int>).evaluate().length}',
          watchesDestination: target.watchDestination,
        );
      }

      final watched = await inspect(
        MorphTarget(
          tag: 'benchmark-stationary-group-watched',
          duration: const Duration(milliseconds: 640),
          watchDestination: true,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      final control = await inspect(
        MorphTarget(tag: 'benchmark-stationary-group-control', duration: const Duration(milliseconds: 640)),
      );

      expect(
        (watched.geometry, control.geometry, watched.watchesDestination, control.watchesDestination),
        (watched.geometry, watched.geometry, true, false),
      );
    });

    testWidgets('when the full-surface workload finishes its mutation batches, '
        'it should stop capturing until the pixels change again', (tester) async {
      final morphObserver = MorphNavigatorObserver();
      final target = MorphTarget(tag: 'benchmark', duration: const Duration(seconds: 1), watchDestination: true);
      tester.view
        ..devicePixelRatio = 3
        ..physicalSize = const Size(1080, 2256);
      addTearDown(tester.view.reset);
      final expanded = ValueNotifier(false);
      final dirty = MorphBenchmarkSnapshotPaintProbe(capturesOnly: true);
      final clean = MorphBenchmarkSnapshotPaintProbe(capturesOnly: true);
      addTearDown(expanded.dispose);
      addTearDown(dirty.dispose);
      addTearDown(clean.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [morphObserver],
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: expanded,
              builder: (context, value, child) {
                return MorphBenchmarkWorkloads.watchedSnapshotFullSurface(
                  target: target,
                  expanded: value,
                  surfaceChanges: dirty.changes,
                  dirtySnapshotPainter: dirty,
                  unchangedSnapshotPainter: clean,
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
      await tester.pump(const Duration(milliseconds: 100));
      final firstEvent = dirty.paintEventCount;
      for (var batch = 0; batch < 12; batch += 1) {
        dirty.requestMutationBatch(mutations: 1);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      expect(dirty.measureSince(firstEvent).capturePaints, 12);
    });

    for (final registered in [false, true]) {
      testWidgets('when a dynamic watched workload changes '
          'with registration $registered, '
          'it should capture each dirty generation once and preserve the control', (tester) async {
        final morphObserver = MorphNavigatorObserver();
        final target = MorphTarget(tag: 'benchmark', duration: const Duration(seconds: 1), watchDestination: true);
        final expanded = ValueNotifier(false);
        final dirty = MorphBenchmarkSnapshotPaintProbe(capturesOnly: true);
        final clean = MorphBenchmarkSnapshotPaintProbe(capturesOnly: true);
        addTearDown(expanded.dispose);
        addTearDown(dirty.dispose);
        addTearDown(clean.dispose);
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
                    registeredContent: registered,
                    dynamicWatchedSnapshot: true,
                    surfaceChanges: dirty.changes,
                    dirtySnapshotPainter: dirty,
                    unchangedSnapshotPainter: clean,
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
        await tester.pump(const Duration(milliseconds: 100));
        final dirtyStart = dirty.paintEventCount;
        final cleanStart = clean.paintEventCount;
        for (var batch = 0; batch < 4; batch += 1) {
          dirty.requestMutationBatch();
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pumpAndSettle();

        expect(
          (dirty.measureSince(dirtyStart).capturedGenerations.join(','), clean.measureSince(cleanStart).capturePaints),
          ('3,6,9,12', 0),
        );
      });
    }

    for (final (name, behavior) in const [
      ('live', MorphDescendantFlightBehavior.live()),
      ('snapshot', MorphDescendantFlightBehavior.snapshot()),
      ('hide', MorphDescendantFlightBehavior.hide()),
    ]) {
      testWidgets('when the $name descendant workload is built, '
          'it should configure the requested flight behavior', (tester) async {
        final morphObserver = MorphNavigatorObserver();
        final target = MorphTarget(tag: 'benchmark', duration: const Duration(milliseconds: 320));
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [morphObserver],
            home: Scaffold(
              body: MorphBenchmarkWorkloads.descendant(target: target, expanded: false, behavior: behavior),
            ),
          ),
        );

        final descendant = tester.widget<MorphDescendant>(find.byType(MorphDescendant));
        expect(descendant.flightBehavior, behavior);
      });
    }

    testWidgets('when the dense snapshot workload is built, '
        'it should contain twenty-four sibling snapshot descendants', (tester) async {
      final morphObserver = MorphNavigatorObserver();
      final target = MorphTarget(tag: 'benchmark', duration: const Duration(milliseconds: 320));
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [morphObserver],
          home: Scaffold(body: MorphBenchmarkWorkloads.descendantSnapshotDense(target: target, expanded: false)),
        ),
      );

      expect(find.byType(MorphDescendant), findsNWidgets(24));
    });

    testWidgets('when the dense snapshot workload watches its destination, '
        'it should enable destination watching', (tester) async {
      final morphObserver = MorphNavigatorObserver();
      final target = MorphTarget(tag: 'benchmark', duration: const Duration(milliseconds: 320), watchDestination: true);
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [morphObserver],
          home: Scaffold(body: MorphBenchmarkWorkloads.descendantSnapshotDense(target: target, expanded: false)),
        ),
      );

      expect(target.watchDestination, isTrue);
    });

    testWidgets('when the dynamic dense snapshot workload is built, '
        'it should track one dirty descendant and preserve one control', (tester) async {
      final morphObserver = MorphNavigatorObserver();
      final target = MorphTarget(tag: 'benchmark', duration: const Duration(milliseconds: 320), watchDestination: true);
      final dirtyProbe = MorphBenchmarkSnapshotPaintProbe();
      final unchangedProbe = MorphBenchmarkSnapshotPaintProbe();
      addTearDown(dirtyProbe.dispose);
      addTearDown(unchangedProbe.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [morphObserver],
          home: Scaffold(
            body: MorphBenchmarkWorkloads.descendantSnapshotDense(
              target: target,
              expanded: false,
              dynamicWatchedSnapshot: true,
              surfaceChanges: dirtyProbe.changes,
              dirtySnapshotPainter: dirtyProbe,
              unchangedSnapshotPainter: unchangedProbe,
            ),
          ),
        ),
      );

      final descendants = tester.widgetList<MorphDescendant>(find.byType(MorphDescendant));
      final dirtyDescendant = find.byKey(const ValueKey<int>(0));
      final nestedRepaintBoundaries = find.descendant(of: dirtyDescendant, matching: find.byType(RepaintBoundary));
      final surface = find.byKey(const ValueKey<String>('benchmark-watch_snapshot_dynamic-surface-source'));
      final initialRect = tester.getRect(surface);

      dirtyProbe.requestMutationBatch();
      await tester.pump();
      final changedRect = tester.getRect(surface);

      expect(
        (
          target.watchDestination,
          descendants.length,
          nestedRepaintBoundaries.evaluate().length,
          changedRect != initialRect,
          dirtyProbe.requestedGeneration,
        ),
        (true, 24, 0, true, 3),
      );
    });

    testWidgets('when the geometry-only watched snapshot workload changes, '
        'it should move the surface without repainting descendant pixels', (tester) async {
      final morphObserver = MorphNavigatorObserver();
      final target = MorphTarget(tag: 'benchmark', duration: const Duration(milliseconds: 320), watchDestination: true);
      final geometryChanges = ValueNotifier<int>(0);
      final dirtyProbe = MorphBenchmarkSnapshotPaintProbe();
      final unchangedProbe = MorphBenchmarkSnapshotPaintProbe();
      addTearDown(geometryChanges.dispose);
      addTearDown(dirtyProbe.dispose);
      addTearDown(unchangedProbe.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [morphObserver],
          home: Scaffold(
            body: MorphBenchmarkWorkloads.descendantSnapshotDense(
              target: target,
              expanded: false,
              geometryOnlyWatchedSnapshot: true,
              surfaceChanges: geometryChanges,
              dirtySnapshotPainter: dirtyProbe,
              unchangedSnapshotPainter: unchangedProbe,
            ),
          ),
        ),
      );

      final descendants = tester.widgetList<MorphDescendant>(find.byType(MorphDescendant));
      final surface = find.byKey(const ValueKey<String>('benchmark-watch_snapshot_geometry_only-surface-source'));
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
    });

    testWidgets('when the full-surface watched snapshot workload changes, '
        'it should resize one automatically tracked near-full descendant only', (tester) async {
      final morphObserver = MorphNavigatorObserver();
      final target = MorphTarget(tag: 'benchmark', duration: const Duration(milliseconds: 320), watchDestination: true);
      final dirtyProbe = MorphBenchmarkSnapshotPaintProbe();
      final unchangedProbe = MorphBenchmarkSnapshotPaintProbe();
      addTearDown(dirtyProbe.dispose);
      addTearDown(unchangedProbe.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [morphObserver],
          home: Scaffold(
            body: MorphBenchmarkWorkloads.watchedSnapshotFullSurface(
              target: target,
              expanded: false,
              surfaceChanges: dirtyProbe.changes,
              dirtySnapshotPainter: dirtyProbe,
              unchangedSnapshotPainter: unchangedProbe,
            ),
          ),
        ),
      );

      final changingDescendant = find.byKey(const ValueKey<String>('full-surface-dirty'));
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
    });

    testWidgets('when the nested fallback snapshot workload is built, '
        'it should independently repaint one nested boundary', (tester) async {
      final morphObserver = MorphNavigatorObserver();
      final target = MorphTarget(tag: 'benchmark', duration: const Duration(milliseconds: 320), watchDestination: true);
      final dirtyProbe = MorphBenchmarkSnapshotPaintProbe();
      final unchangedProbe = MorphBenchmarkSnapshotPaintProbe();
      addTearDown(dirtyProbe.dispose);
      addTearDown(unchangedProbe.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [morphObserver],
          home: Scaffold(
            body: MorphBenchmarkWorkloads.descendantSnapshotDense(
              target: target,
              expanded: false,
              nestedSnapshotFallback: true,
              dirtySnapshotPainter: dirtyProbe,
              unchangedSnapshotPainter: unchangedProbe,
            ),
          ),
        ),
      );

      final descendantFinder = find.byType(MorphDescendant);
      final widgetList = tester.widgetList<MorphDescendant>(descendantFinder);
      final descendants = List<MorphDescendant>.of(widgetList, growable: false);
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
    });

    testWidgets('when the matched raw Column workload flies, '
        'it should use the resizing hybrid slot', (tester) async {
      final morphObserver = MorphNavigatorObserver();
      final target = MorphTarget(tag: 'benchmark', duration: const Duration(milliseconds: 320));
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
          navigatorObservers: [morphObserver],
          home: Scaffold(
            body: _WorkloadHarness(
              key: harnessKey,
              builder: ({required expanded}) {
                return MorphBenchmarkWorkloads.columnMatchedRawResize(target: target, expanded: expanded);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      harnessKey.currentState!.showDestination();
      await tester.pump();
      await tester.pump();
      final overlay = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MorphOverlay');
      final hybrid = find.descendant(
        of: overlay,
        matching: find.byWidgetPredicate((widget) => widget.runtimeType.toString() == hybridRenderWidgetName),
      );
      final rawSlots = find.descendant(
        of: hybrid,
        matching: find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MorphHybridRawSlot'),
      );
      final initialSizes = rawSlots
          .evaluate()
          .map((element) => tester.getSize(find.byElementPredicate((candidate) => identical(candidate, element))))
          .toList(growable: false);
      await tester.pump(const Duration(milliseconds: 40));
      final resizedSizes = rawSlots
          .evaluate()
          .map((element) => tester.getSize(find.byElementPredicate((candidate) => identical(candidate, element))))
          .toList(growable: false);
      final initialRaw = initialSizes.reduce(largestSize);
      final resizedRaw = resizedSizes.reduce(largestSize);

      expect(
        (
          hybrid.evaluate().length,
          rawSlots.evaluate().length,
          find
              .descendant(of: overlay, matching: find.byKey(const ValueKey<String>('matched-resizing-raw-child')))
              .evaluate()
              .length,
          resizedRaw.width > initialRaw.width,
          resizedRaw.height > initialRaw.height,
          tester.takeException(),
        ),
        (1, 1, 1, true, true, null),
      );
    });

    testWidgets('when the nested watch workload is built, '
        'it should configure the child and parent timing contract', (tester) async {
      final childTarget = MorphTarget(
        tag: 'nested-child',
        duration: MorphBenchmarkWorkloads.nestedWatchChildDuration,
        watchDestination: true,
      );
      final morphObserver = MorphNavigatorObserver();
      final target = MorphTarget(tag: 'benchmark', duration: MorphBenchmarkWorkloads.nestedWatchParentDuration);
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [morphObserver],
          home: Scaffold(
            body: MorphBenchmarkWorkloads.nestedWatchHold(childTarget: childTarget, target: target, expanded: false),
          ),
        ),
      );
      final morphs = tester
          .widgetList<Morph>(find.byWidgetPredicate((widget) => widget is Morph))
          .toList(growable: false);
      final child = morphs.singleWhere((morph) => identical(morph.targets.single, childTarget));
      final parent = morphs.singleWhere((morph) => identical(morph.targets.single, target));
      final targetMotion = tester.widget<TweenAnimationBuilder<double>>(
        find.byKey(const ValueKey<String>('nested-watch-motion')),
      );

      expect(
        (
          child.targets.single.watchDestination,
          child.targets.single.duration,
          parent.targets.single.duration,
          targetMotion.duration,
        ),
        (true, const Duration(milliseconds: 160), const Duration(milliseconds: 640), const Duration(milliseconds: 640)),
      );
    });

    testWidgets('when the watched child has finished, '
        'it should remain held while its target continues moving', (tester) async {
      final childTarget = MorphTarget(
        tag: 'nested-child',
        duration: MorphBenchmarkWorkloads.nestedWatchChildDuration,
        watchDestination: true,
      );
      final morphObserver = MorphNavigatorObserver();
      final target = MorphTarget(tag: 'benchmark', duration: MorphBenchmarkWorkloads.nestedWatchParentDuration);
      final harnessKey = GlobalKey<_WorkloadHarnessState>();
      var parentEnded = false;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [morphObserver],
          home: Scaffold(
            body: _WorkloadHarness(
              key: harnessKey,
              builder: ({required expanded}) {
                return MorphBenchmarkWorkloads.nestedWatchHold(
                  childTarget: childTarget,
                  target: target,
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
      final overlay = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MorphOverlay');
      final activeFlightBoundaries = find.descendant(
        of: overlay,
        matching: find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MorphFlightBoundary'),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final activeFlightBoundaryCount = activeFlightBoundaries.evaluate().length;
      await tester.pump(const Duration(milliseconds: 100));
      final heldFlightBoundaryCount = activeFlightBoundaries.evaluate().length;
      final destination = find.byKey(
        const ValueKey<String>('benchmark-nested_watch_hold-nested-watch-parent-destination'),
        skipOffstage: false,
      );
      final destinationFinder = find.descendant(
        of: destination,
        matching: find.byKey(const ValueKey<String>('nested-watch-target-geometry'), skipOffstage: false),
        skipOffstage: false,
      );
      final heldRect = tester.getRect(destinationFinder);
      await tester.pump(const Duration(milliseconds: 100));
      final movedRect = tester.getRect(destinationFinder);

      expect(activeFlightBoundaryCount, greaterThan(1));
      expect(
        (heldFlightBoundaryCount, movedRect != heldRect, parentEnded, tester.takeException()),
        (activeFlightBoundaryCount, true, false, null),
      );
    });
  });
}

class _WorkloadHarness extends StatefulWidget {
  const new({required this.builder, super.key});

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
