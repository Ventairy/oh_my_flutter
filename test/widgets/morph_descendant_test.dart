import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class _DeepMorphDescendant extends StatelessWidget {
  const _DeepMorphDescendant({
    required this.scrollController,
    required this.flightBehavior,
  });

  final ScrollController scrollController;
  final MorphDescendantFlightBehavior flightBehavior;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: DecoratedBox(
        decoration: const BoxDecoration(),
        child: Align(
          child: MorphDescendant(
            flightBehavior: flightBehavior,
            child: SizedBox(
              width: 120,
              height: 120,
              child: SingleChildScrollView(
                controller: scrollController,
                child: const SizedBox(height: 400),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MorphDescendantRouteTestApp extends StatelessWidget {
  const _MorphDescendantRouteTestApp({
    required this.scrollController,
    this.flightBehavior = MorphDescendantFlightBehavior.snapshot,
  });

  final ScrollController scrollController;
  final MorphDescendantFlightBehavior flightBehavior;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Column(
              children: [
                Morph(
                  tag: 'descendant-route',
                  child: Container(
                    width: 200,
                    height: 200,
                    color: Colors.red,
                    child: _DeepMorphDescendant(
                      scrollController: scrollController,
                      flightBehavior: flightBehavior,
                    ),
                  ),
                ),
                FilledButton(
                  key: const ValueKey('open-destination'),
                  onPressed: () {
                    unawaited(
                      Navigator.of(context).push<void>(
                        PageRouteBuilder<void>(
                          opaque: false,
                          transitionDuration: const Duration(milliseconds: 400),
                          pageBuilder: (context, animation, secondaryAnimation) {
                            return Align(
                              key: const ValueKey('destination'),
                              alignment: Alignment.bottomRight,
                              child: Morph(
                                tag: 'descendant-route',
                                child: Container(
                                  width: 300,
                                  height: 300,
                                  color: Colors.blue,
                                ),
                              ),
                            );
                          },
                          transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Finder get _snapshotPaint => find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == '_MorphContentSnapshotPainter',
);

void main() {
  testWidgets(
    'when a live descendant is nested deeply, it should mount a responsive flight copy',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        _MorphDescendantRouteTestApp(
          scrollController: scrollController,
          flightBehavior: MorphDescendantFlightBehavior.live,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-destination')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(scrollController.positions.length, 2);
    },
  );

  testWidgets(
    'when a snapshot descendant is nested deeply, it should keep the stateful child attached only to its endpoint',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        _MorphDescendantRouteTestApp(scrollController: scrollController),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-destination')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(scrollController.positions.length, 1);
    },
  );

  testWidgets(
    'when a snapshot descendant owns an active keyed text field, '
    'it should keep one focused endpoint instance during the flight',
    (tester) async {
      final fieldKey = GlobalKey();
      final focusNode = FocusNode();
      final textController = TextEditingController(text: 'Editable value');
      addTearDown(focusNode.dispose);
      addTearDown(textController.dispose);
      var expanded = false;
      late StateSetter setHarnessState;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setHarnessState = setState;
                  return Morph(
                    tag: 'keyed-editor',
                    child: SizedBox(
                      key: ValueKey<bool>(expanded),
                      width: expanded ? 260 : 180,
                      child: MorphDescendant(
                        flightBehavior: MorphDescendantFlightBehavior.snapshot,
                        child: TextField(
                          key: fieldKey,
                          controller: textController,
                          focusNode: focusNode,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      setHarnessState(() => expanded = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(
        (
          find.byKey(fieldKey).evaluate().length,
          focusNode.hasFocus,
          tester.takeException(),
        ),
        (1, true, null),
      );
    },
  );

  testWidgets(
    'when a snapshot descendant is nested deeply, it should paint its captured appearance during the flight',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        _MorphDescendantRouteTestApp(scrollController: scrollController),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-destination')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(_snapshotPaint, findsOneWidget);
    },
  );

  testWidgets(
    'when a snapshot descendant returns from another route, it should preserve its scroll offset',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        _MorphDescendantRouteTestApp(scrollController: scrollController),
      );
      await tester.pumpAndSettle();
      scrollController.jumpTo(120);

      await tester.tap(find.byKey(const ValueKey('open-destination')));
      await tester.pumpAndSettle();
      Navigator.of(
        tester.element(find.byKey(const ValueKey('destination'))),
      ).pop();
      await tester.pumpAndSettle();

      expect(scrollController.offset, 120);
    },
  );

  testWidgets(
    'when a snapshot destination returns after its earlier capture was released, '
    'it should paint a fresh destination snapshot',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        _MorphDescendantRouteTestApp(scrollController: scrollController),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-destination')));
      await tester.pumpAndSettle();

      Navigator.of(
        tester.element(find.byKey(const ValueKey('destination'))),
      ).pop();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        (_snapshotPaint.evaluate().length, tester.takeException()),
        (1, null),
      );
    },
  );

  testWidgets(
    'when a hidden descendant is nested deeply, it should mount no flight copy or snapshot',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        _MorphDescendantRouteTestApp(
          scrollController: scrollController,
          flightBehavior: MorphDescendantFlightBehavior.hide,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-destination')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      expect(
        (scrollController.positions.length, _snapshotPaint.evaluate().length),
        (1, 0),
      );
    },
  );

  testWidgets(
    'when one endpoint contains several snapshot descendants, '
    'it should capture one shared image per endpoint',
    (tester) async {
      var expanded = false;
      late StateSetter setHarnessState;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setHarnessState = setState;
              return Morph(
                tag: 'snapshot-atlas',
                child: Container(
                  key: ValueKey<bool>(expanded),
                  width: expanded ? 240 : 160,
                  height: expanded ? 180 : 120,
                  color: expanded ? Colors.blue : Colors.red,
                  child: Row(
                    children: List<Widget>.generate(
                      3,
                      (index) => MorphDescendant(
                        key: ValueKey<int>(index),
                        flightBehavior: MorphDescendantFlightBehavior.snapshot,
                        child: SizedBox.square(
                          dimension: expanded ? 48 : 32,
                          child: ColoredBox(
                            color: Color(0xFF000000 + index),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      var imageCreations = 0;
      final previousOnCreate = ui.Image.onCreate;
      void handleImageCreated(ui.Image image) {
        previousOnCreate?.call(image);
        imageCreations += 1;
      }

      ui.Image.onCreate = handleImageCreated;
      addTearDown(() {
        if (identical(ui.Image.onCreate, handleImageCreated)) {
          ui.Image.onCreate = previousOnCreate;
        }
      });

      setHarnessState(() => expanded = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect((imageCreations, _snapshotPaint.evaluate().length), (2, 3));
    },
  );

  testWidgets(
    'when a snapshot descendant contains another snapshot descendant, '
    'it should capture only the outer boundary',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      var expanded = false;
      late StateSetter setHarnessState;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setHarnessState = setState;
              final outerSize = expanded ? 120.0 : 100.0;
              final innerSize = expanded ? 50.0 : 40.0;
              return Align(
                child: Morph(
                  tag: 'nested-snapshot',
                  child: SizedBox.square(
                    key: ValueKey<bool>(expanded),
                    dimension: outerSize,
                    child: MorphDescendant(
                      flightBehavior: MorphDescendantFlightBehavior.snapshot,
                      child: ColoredBox(
                        color: Colors.red,
                        child: Center(
                          child: SizedBox.square(
                            dimension: innerSize,
                            child: const MorphDescendant(
                              flightBehavior: MorphDescendantFlightBehavior.snapshot,
                              child: ColoredBox(color: Colors.blue),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      var imageCreations = 0;
      var largestImagePixels = 0;
      final previousOnCreate = ui.Image.onCreate;
      void handleImageCreated(ui.Image image) {
        previousOnCreate?.call(image);
        imageCreations += 1;
        largestImagePixels = math.max(
          largestImagePixels,
          image.width * image.height,
        );
      }

      ui.Image.onCreate = handleImageCreated;
      addTearDown(() {
        if (identical(ui.Image.onCreate, handleImageCreated)) {
          ui.Image.onCreate = previousOnCreate;
        }
      });

      setHarnessState(() => expanded = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect((imageCreations, largestImagePixels), (2, 14400));
    },
  );

  testWidgets(
    'when a snapshot flight crosses the switch threshold, '
    'it should replace the source snapshot with the destination snapshot',
    (tester) async {
      var expanded = false;
      late StateSetter setHarnessState;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            child: StatefulBuilder(
              builder: (context, setState) {
                setHarnessState = setState;
                return Morph(
                  tag: 'snapshot-switch',
                  child: ColoredBox(
                    key: ValueKey<bool>(expanded),
                    color: expanded ? Colors.blue : Colors.red,
                    child: MorphDescendant(
                      key: const ValueKey<String>('snapshot-content'),
                      flightBehavior: MorphDescendantFlightBehavior.snapshot,
                      child: SizedBox(
                        width: expanded ? 80 : 40,
                        height: expanded ? 60 : 30,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      setHarnessState(() => expanded = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final sourceSize = tester.getSize(_snapshotPaint);
      await tester.pump(const Duration(milliseconds: 100));
      final destinationSize = tester.getSize(_snapshotPaint);

      expect((sourceSize, destinationSize), (const Size(40, 30), const Size(80, 60)));
    },
  );

  testWidgets(
    'when both endpoints reuse one snapshot descendant widget, '
    'it should still switch to the destination snapshot size',
    (tester) async {
      const descendant = MorphDescendant(
        flightBehavior: MorphDescendantFlightBehavior.snapshot,
        child: SizedBox.expand(
          child: ColoredBox(color: Colors.blue),
        ),
      );
      var expanded = false;
      late StateSetter setHarnessState;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            child: StatefulBuilder(
              builder: (context, setState) {
                setHarnessState = setState;
                return Morph(
                  tag: 'reused-snapshot-switch',
                  child: SizedBox(
                    key: ValueKey<bool>(expanded),
                    width: expanded ? 120 : 80,
                    height: expanded ? 90 : 60,
                    child: descendant,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      setHarnessState(() => expanded = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final sourceSize = tester.getSize(_snapshotPaint);
      await tester.pump(const Duration(milliseconds: 100));
      final destinationSize = tester.getSize(_snapshotPaint);

      expect(
        (sourceSize, destinationSize),
        (const Size(80, 60), const Size(120, 90)),
      );
    },
  );

  testWidgets(
    'when a specialized container contains a snapshot descendant, '
    'it should preserve the descendant configuration in its flight',
    (tester) async {
      var expanded = false;
      late StateSetter setHarnessState;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            child: StatefulBuilder(
              builder: (context, setState) {
                setHarnessState = setState;
                return Morph(
                  tag: 'container-snapshot',
                  child: Container(
                    key: ValueKey<bool>(expanded),
                    width: expanded ? 180 : 120,
                    height: expanded ? 140 : 90,
                    decoration: BoxDecoration(
                      color: expanded ? Colors.blue : Colors.red,
                      borderRadius: BorderRadius.circular(
                        expanded ? 32 : 16,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: MorphDescendant(
                      key: const ValueKey<String>('container-content'),
                      flightBehavior: MorphDescendantFlightBehavior.snapshot,
                      child: SizedBox(
                        width: expanded ? 80 : 40,
                        height: expanded ? 60 : 30,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      setHarnessState(() => expanded = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.getSize(_snapshotPaint), const Size(80, 60));
    },
  );

  testWidgets(
    'when endpoint descendant behaviors differ, '
    'it should use the behavior of the currently selected endpoint',
    (tester) async {
      var expanded = false;
      late StateSetter setHarnessState;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            child: StatefulBuilder(
              builder: (context, setState) {
                setHarnessState = setState;
                return Morph(
                  tag: 'mixed-descendant-behavior',
                  child: SizedBox.square(
                    key: ValueKey<bool>(expanded),
                    dimension: expanded ? 120 : 80,
                    child: MorphDescendant(
                      key: const ValueKey<String>('mixed-content'),
                      flightBehavior: expanded
                          ? MorphDescendantFlightBehavior.snapshot
                          : MorphDescendantFlightBehavior.live,
                      child: const ColoredBox(color: Colors.blue),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      setHarnessState(() => expanded = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final beforeThreshold = _snapshotPaint.evaluate().length;
      await tester.pump(const Duration(milliseconds: 100));
      final afterThreshold = _snapshotPaint.evaluate().length;

      expect((beforeThreshold, afterThreshold), (0, 1));
    },
  );

  testWidgets(
    'when animations are disabled, '
    'it should transfer snapshot descendants without capturing images',
    (tester) async {
      var expanded = false;
      late StateSetter setHarnessState;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Align(
              child: StatefulBuilder(
                builder: (context, setState) {
                  setHarnessState = setState;
                  return Morph(
                    tag: 'reduced-motion-snapshot',
                    child: SizedBox.square(
                      key: ValueKey<bool>(expanded),
                      dimension: expanded ? 120 : 80,
                      child: const MorphDescendant(
                        flightBehavior: MorphDescendantFlightBehavior.snapshot,
                        child: ColoredBox(color: Colors.blue),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var imageCreations = 0;
      final previousOnCreate = ui.Image.onCreate;
      void handleImageCreated(ui.Image image) {
        previousOnCreate?.call(image);
        imageCreations += 1;
      }

      ui.Image.onCreate = handleImageCreated;
      addTearDown(() {
        if (identical(ui.Image.onCreate, handleImageCreated)) {
          ui.Image.onCreate = previousOnCreate;
        }
      });

      setHarnessState(() => expanded = true);
      await tester.pump();
      await tester.pump();

      expect(imageCreations, 0);
    },
  );
}
