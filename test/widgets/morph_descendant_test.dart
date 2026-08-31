import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

class _SnapshotTestPainter extends CustomPainter {
  const _SnapshotTestPainter({
    required this.color,
    required this.throwsOnPaint,
  });

  final Color color;
  final bool throwsOnPaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (throwsOnPaint) {
      throw StateError('Watched snapshot capture failed.');
    }
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SnapshotTestPainter oldDelegate) {
    return color != oldDelegate.color || throwsOnPaint != oldDelegate.throwsOnPaint;
  }
}

class _CountingSnapshotPainter extends CustomPainter {
  const _CountingSnapshotPainter({
    required this.color,
    required this.revision,
    required this.onPaint,
  });

  final Color color;
  final int revision;
  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CountingSnapshotPainter oldDelegate) {
    return revision != oldDelegate.revision || color != oldDelegate.color;
  }
}

class _ListenableSnapshotPainter extends CustomPainter {
  _ListenableSnapshotPainter(this.color) : super(repaint: color);

  final ValueListenable<Color> color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color.value);
  }

  @override
  bool shouldRepaint(_ListenableSnapshotPainter oldDelegate) => false;
}

Finder get _snapshotPaint => find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == '_MorphContentSnapshotPainter',
);

Future<Color> _pixelAt(
  WidgetTester tester, {
  required Finder boundaryFinder,
  required Offset position,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    final x = position.dx.round().clamp(0, image.width - 1);
    final y = position.dy.round().clamp(0, image.height - 1);
    final offset = (y * image.width + x) * 4;
    final color = Color.fromARGB(
      bytes!.getUint8(offset + 3),
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    );
    image.dispose();
    return color;
  }))!;
}

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
    'when one snapshot needs tiling within the total image budget, '
    'it should divide the image into bounded tiles',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(4300, 1000);
      addTearDown(() {
        tester.view
          ..resetDevicePixelRatio()
          ..resetPhysicalSize();
      });
      var destination = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Align(
                child: Morph(
                  tag: 'large-snapshot-tiling',
                  child: SizedBox(
                    key: ValueKey<bool>(destination),
                    width: 4200,
                    height: 900,
                    child: const MorphDescendant(
                      flightBehavior: MorphDescendantFlightBehavior.snapshot,
                      child: ColoredBox(color: Colors.blue),
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
      var liveImagePixels = 0;
      var maximumLiveImagePixels = 0;
      final previousOnCreate = ui.Image.onCreate;
      final previousOnDispose = ui.Image.onDispose;
      void handleImageCreated(ui.Image image) {
        previousOnCreate?.call(image);
        imageCreations += 1;
        final pixels = image.width * image.height;
        largestImagePixels = math.max(largestImagePixels, pixels);
        liveImagePixels += pixels;
        maximumLiveImagePixels = math.max(
          maximumLiveImagePixels,
          liveImagePixels,
        );
      }

      void handleImageDisposed(ui.Image image) {
        previousOnDispose?.call(image);
        liveImagePixels -= image.width * image.height;
      }

      ui.Image.onCreate = handleImageCreated;
      ui.Image.onDispose = handleImageDisposed;
      addTearDown(() {
        if (identical(ui.Image.onCreate, handleImageCreated)) {
          ui.Image.onCreate = previousOnCreate;
        }
        if (identical(ui.Image.onDispose, handleImageDisposed)) {
          ui.Image.onDispose = previousOnDispose;
        }
      });

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      ui.Image.onCreate = previousOnCreate;
      ui.Image.onDispose = previousOnDispose;

      expect(
        (
          imageCreations > 1,
          largestImagePixels <= 2048 * 2048,
          maximumLiveImagePixels <= 2 * 2048 * 2048,
          liveImagePixels,
        ),
        (true, true, true, 0),
      );
    },
  );

  testWidgets(
    'when one snapshot exceeds the total image budget, '
    'it should avoid allocating snapshot images',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(2200, 2200);
      addTearDown(() {
        tester.view
          ..resetDevicePixelRatio()
          ..resetPhysicalSize();
      });
      var destination = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Align(
                child: Morph(
                  tag: 'snapshot-total-budget',
                  child: SizedBox.square(
                    key: ValueKey<bool>(destination),
                    dimension: 2100,
                    child: const MorphDescendant(
                      flightBehavior: MorphDescendantFlightBehavior.snapshot,
                      child: ColoredBox(color: Colors.blue),
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

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      ui.Image.onCreate = previousOnCreate;

      expect(
        (imageCreations, _snapshotPaint.evaluate().length),
        (0, 0),
      );
    },
  );

  testWidgets(
    'when atlas packing exceeds the total image budget, '
    'it should avoid allocating partial snapshot images',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1600, 4100);
      addTearDown(() {
        tester.view
          ..resetDevicePixelRatio()
          ..resetPhysicalSize();
      });
      var destination = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Morph(
                  tag: 'snapshot-packed-total-budget',
                  child: Column(
                    key: ValueKey<bool>(destination),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      MorphDescendant(
                        flightBehavior: MorphDescendantFlightBehavior.snapshot,
                        child: SizedBox(
                          width: 1500,
                          height: 500,
                          child: ColoredBox(color: Colors.blue),
                        ),
                      ),
                      MorphDescendant(
                        flightBehavior: MorphDescendantFlightBehavior.snapshot,
                        child: SizedBox(
                          width: 500,
                          height: 1500,
                          child: ColoredBox(color: Colors.green),
                        ),
                      ),
                      MorphDescendant(
                        flightBehavior: MorphDescendantFlightBehavior.snapshot,
                        child: SizedBox(
                          width: 1500,
                          height: 500,
                          child: ColoredBox(color: Colors.orange),
                        ),
                      ),
                      MorphDescendant(
                        flightBehavior: MorphDescendantFlightBehavior.snapshot,
                        child: SizedBox(
                          width: 500,
                          height: 1500,
                          child: ColoredBox(color: Colors.purple),
                        ),
                      ),
                    ],
                  ),
                );
              },
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

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      ui.Image.onCreate = previousOnCreate;

      expect(imageCreations, 0);
    },
  );

  testWidgets(
    'when a tiled snapshot has a fractional terminal extent, '
    'it should preserve the painted edge coverage',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(4100, 100);
      addTearDown(() {
        tester.view
          ..resetDevicePixelRatio()
          ..resetPhysicalSize();
      });
      const frameKey = ValueKey<String>('fractional-tile-frame');
      var destination = false;
      late StateSetter update;
      await tester.pumpWidget(
        RepaintBoundary(
          key: frameKey,
          child: MaterialApp(
            home: ColoredBox(
              color: Colors.white,
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Morph(
                      tag: 'fractional-snapshot-tile',
                      duration: const Duration(milliseconds: 400),
                      child: SizedBox(
                        key: ValueKey<bool>(destination),
                        width: 4096.5,
                        height: 40,
                        child: const MorphDescendant(
                          flightBehavior: MorphDescendantFlightBehavior.snapshot,
                          child: CustomPaint(
                            painter: _SnapshotTestPainter(
                              color: Colors.red,
                              throwsOnPaint: false,
                            ),
                          ),
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
      await tester.pumpAndSettle();

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final snapshotRect = tester.getRect(_snapshotPaint);
      final edgePixel = await _pixelAt(
        tester,
        boundaryFinder: find.byKey(frameKey),
        position: Offset(snapshotRect.right - 0.6, snapshotRect.center.dy),
      );

      expect(edgePixel.toARGB32(), const Color(0xFFFAA19B).toARGB32());
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
    'when a watched destination snapshot changes during a flight, '
    'it should refresh its geometry and pixels before handoff',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      const frameKey = ValueKey<String>('watched-snapshot-frame');
      final descendantKey = GlobalKey();
      var destination = false;
      var destinationSize = const Size(80, 60);
      var destinationColor = Colors.blue;
      late StateSetter update;
      await tester.pumpWidget(
        RepaintBoundary(
          key: frameKey,
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Align(
                    alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                    child: Morph(
                      tag: 'watched-snapshot-refresh',
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.linear,
                      watchDestination: !destination,
                      child: SizedBox(
                        key: ValueKey<bool>(destination),
                        width: destination ? destinationSize.width + 40 : 120,
                        height: destination ? destinationSize.height + 40 : 100,
                        child: Center(
                          child: MorphDescendant(
                            key: const ValueKey<String>(
                              'watched-snapshot-content',
                            ),
                            flightBehavior: MorphDescendantFlightBehavior.snapshot,
                            child: SizedBox.fromSize(
                              size: destination ? destinationSize : const Size(40, 30),
                              child: ColoredBox(
                                key: descendantKey,
                                color: destination ? destinationColor : Colors.red,
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final initialSize = tester.getSize(_snapshotPaint);
      final initialCenter = tester.getCenter(_snapshotPaint);
      final initialPixel = await _pixelAt(
        tester,
        boundaryFinder: find.byKey(frameKey),
        position: initialCenter,
      );

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
      update(() {
        destinationSize = const Size(100, 75);
        destinationColor = Colors.yellow;
      });
      update(() {
        destinationSize = const Size(120, 90);
        destinationColor = Colors.green;
      });
      await tester.pump();
      final coalescedImageCreations = imageCreations;
      ui.Image.onCreate = previousOnCreate;
      await tester.pump();
      final refreshedSize = tester.getSize(_snapshotPaint);
      final refreshedCenter = tester.getCenter(_snapshotPaint);
      final refreshedPixel = await _pixelAt(
        tester,
        boundaryFinder: find.byKey(frameKey),
        position: refreshedCenter,
      );

      expect(
        (
          initialSize,
          initialPixel.toARGB32(),
          refreshedSize,
          refreshedPixel.toARGB32(),
          coalescedImageCreations,
          find.byKey(descendantKey).evaluate().length,
        ),
        (
          const Size(80, 60),
          Colors.blue.toARGB32(),
          const Size(120, 90),
          Colors.green.toARGB32(),
          1,
          1,
        ),
      );
    },
  );

  testWidgets(
    'when a watched flight waits for its cohort, '
    'it should refresh nested snapshot pixels before handoff',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      const frameKey = ValueKey<String>('watched-cohort-hold-frame');
      final color = ValueNotifier<Color>(Colors.blue);
      addTearDown(color.dispose);
      final painter = _ListenableSnapshotPainter(color);
      var destination = false;
      late StateSetter update;

      Widget shortFlight() {
        return Align(
          alignment: destination ? Alignment.topLeft : Alignment.topRight,
          child: Morph(
            tag: 'watched-short-cohort-flight',
            duration: const Duration(milliseconds: 100),
            curve: Curves.linear,
            watchDestination: !destination,
            child: SizedBox.square(
              key: ValueKey<String>('watched-short-$destination'),
              dimension: 40,
              child: MorphDescendant(
                flightBehavior: MorphDescendantFlightBehavior.snapshot,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: painter,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      Widget longFlight() {
        return Align(
          alignment: destination ? Alignment.bottomCenter : Alignment.topCenter,
          child: Morph(
            tag: 'watched-long-cohort-flight',
            duration: const Duration(milliseconds: 400),
            curve: Curves.linear,
            watchDestination: !destination,
            child: SizedBox(
              key: ValueKey<String>('watched-long-$destination'),
              width: destination ? 180 : 120,
              height: destination ? 100 : 60,
              child: ColoredBox(
                color: destination ? Colors.purple : Colors.orange,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(
        RepaintBoundary(
          key: frameKey,
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: [longFlight(), shortFlight()],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final snapshotsDuringHold = _snapshotPaint.evaluate().length;
      final beforeChange = await _pixelAt(
        tester,
        boundaryFinder: find.byKey(frameKey),
        position: const Offset(20, 20),
      );

      color.value = Colors.green;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      final duringHold = await _pixelAt(
        tester,
        boundaryFinder: find.byKey(frameKey),
        position: const Offset(20, 20),
      );
      await tester.pumpAndSettle();
      final afterHandoff = await _pixelAt(
        tester,
        boundaryFinder: find.byKey(frameKey),
        position: const Offset(20, 20),
      );

      expect(
        (
          snapshotsDuringHold,
          beforeChange.toARGB32(),
          duringHold.toARGB32(),
          afterHandoff.toARGB32(),
        ),
        (
          1,
          Colors.blue.toARGB32(),
          Colors.green.toARGB32(),
          Colors.green.toARGB32(),
        ),
      );
    },
  );

  testWidgets(
    'when a watched destination snapshot remains unchanged during a flight, '
    'it should not capture additional images',
    (tester) async {
      var destination = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Align(
                  alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    tag: 'watched-static-snapshot',
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.linear,
                    watchDestination: !destination,
                    child: SizedBox(
                      key: ValueKey<bool>(destination),
                      width: destination ? 160 : 100,
                      height: destination ? 120 : 80,
                      child: const Center(
                        child: MorphDescendant(
                          flightBehavior: MorphDescendantFlightBehavior.snapshot,
                          child: SizedBox(
                            width: 80,
                            height: 60,
                            child: ColoredBox(color: Colors.blue),
                          ),
                        ),
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

      update(() => destination = true);
      await tester.pump();
      await tester.pump();

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
      for (var frame = 0; frame < 5; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      ui.Image.onCreate = previousOnCreate;

      expect(imageCreations, 0);
    },
  );

  testWidgets(
    'when an unchanged watched snapshot contains a nested Morph boundary, '
    'it should not capture additional images',
    (tester) async {
      var destination = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Align(
                  alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    tag: 'watched-nested-morph-snapshot',
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.linear,
                    watchDestination: !destination,
                    child: SizedBox(
                      key: ValueKey<bool>(destination),
                      width: destination ? 160 : 100,
                      height: destination ? 120 : 80,
                      child: Center(
                        child: MorphDescendant(
                          flightBehavior: MorphDescendantFlightBehavior.snapshot,
                          child: Morph(
                            tag: 'nested-suppressed-content',
                            child: RepaintBoundary(
                              child: ColoredBox(
                                color: Colors.blue,
                                child: SizedBox(
                                  width: destination ? 80 : 60,
                                  height: destination ? 60 : 40,
                                ),
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
        ),
      );
      await tester.pumpAndSettle();

      update(() => destination = true);
      await tester.pump();
      await tester.pump();

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
      for (var frame = 0; frame < 5; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      ui.Image.onCreate = previousOnCreate;

      expect(imageCreations, 0);
    },
  );

  testWidgets(
    'when one watched destination snapshot changes among several, '
    'it should recapture only the changed descendant',
    (tester) async {
      var destination = false;
      var firstRevision = 0;
      var firstPaints = 0;
      var secondPaints = 0;
      late StateSetter update;
      final secondPainter = _CountingSnapshotPainter(
        color: Colors.purple,
        revision: 0,
        onPaint: () => secondPaints += 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Align(
                  alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    tag: 'watched-dirty-subset',
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.linear,
                    watchDestination: !destination,
                    child: Row(
                      key: ValueKey<bool>(destination),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MorphDescendant(
                          key: const ValueKey<String>('first'),
                          flightBehavior: MorphDescendantFlightBehavior.snapshot,
                          child: CustomPaint(
                            size: const Size(50, 40),
                            painter: _CountingSnapshotPainter(
                              color: destination && firstRevision > 0 ? Colors.green : Colors.blue,
                              revision: firstRevision,
                              onPaint: () => firstPaints += 1,
                            ),
                          ),
                        ),
                        MorphDescendant(
                          key: const ValueKey<String>('second'),
                          flightBehavior: MorphDescendantFlightBehavior.snapshot,
                          child: CustomPaint(
                            size: const Size(50, 40),
                            painter: secondPainter,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      firstPaints = 0;
      secondPaints = 0;

      update(() => firstRevision += 1);
      await tester.pump();

      expect((firstPaints, secondPaints), (1, 0));
    },
  );

  testWidgets(
    'when a watched dirty subset would retain oversized shared atlases, '
    'it should compact the destination snapshot generation',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1900, 1900);
      addTearDown(() {
        tester.view
          ..resetDevicePixelRatio()
          ..resetPhysicalSize();
      });
      final colors = List<ValueNotifier<Color>>.generate(
        4,
        (index) => ValueNotifier<Color>(
          index.isEven ? Colors.blue : Colors.red,
        ),
        growable: false,
      );
      for (final color in colors) {
        addTearDown(color.dispose);
      }
      final painters = colors.map(_ListenableSnapshotPainter.new).toList(growable: false);
      const frameKey = ValueKey<String>('watched-atlas-compaction-frame');
      var destination = false;
      late StateSetter update;
      await tester.pumpWidget(
        RepaintBoundary(
          key: frameKey,
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Align(
                  alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    tag: 'watched-atlas-compaction',
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.linear,
                    watchDestination: !destination,
                    child: SizedBox(
                      key: ValueKey<bool>(destination),
                      width: 1808,
                      height: 1808,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List<Widget>.generate(
                          colors.length,
                          (index) => MorphDescendant(
                            key: ValueKey<int>(index),
                            flightBehavior: MorphDescendantFlightBehavior.snapshot,
                            child: CustomPaint(
                              size: const Size.square(900),
                              painter: painters[index],
                            ),
                          ),
                          growable: false,
                        ),
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

      final trackedImages = Map<ui.Image, int>.identity();
      var liveImagePixels = 0;
      var maximumLiveImagePixels = 0;
      final previousOnCreate = ui.Image.onCreate;
      final previousOnDispose = ui.Image.onDispose;
      void handleImageCreated(ui.Image image) {
        previousOnCreate?.call(image);
        final pixels = image.width * image.height;
        trackedImages[image] = pixels;
        liveImagePixels += pixels;
        maximumLiveImagePixels = math.max(
          maximumLiveImagePixels,
          liveImagePixels,
        );
      }

      void handleImageDisposed(ui.Image image) {
        previousOnDispose?.call(image);
        final pixels = trackedImages.remove(image);
        if (pixels != null) liveImagePixels -= pixels;
      }

      ui.Image.onCreate = handleImageCreated;
      ui.Image.onDispose = handleImageDisposed;
      addTearDown(() {
        if (identical(ui.Image.onCreate, handleImageCreated)) {
          ui.Image.onCreate = previousOnCreate;
        }
        if (identical(ui.Image.onDispose, handleImageDisposed)) {
          ui.Image.onDispose = previousOnDispose;
        }
      });

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      colors[1].value = Colors.green;
      colors[2].value = Colors.orange;
      colors[3].value = Colors.purple;
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 160));
      final steadyImagePixels = liveImagePixels;
      ui.Image.onCreate = previousOnCreate;
      ui.Image.onDispose = previousOnDispose;
      final refreshedPixels = <int>[];
      for (var index = 0; index < colors.length; index += 1) {
        final pixel = await _pixelAt(
          tester,
          boundaryFinder: find.byKey(frameKey),
          position: tester.getCenter(_snapshotPaint.at(index)),
        );
        refreshedPixels.add(pixel.toARGB32());
      }
      ui.Image.onCreate = handleImageCreated;
      ui.Image.onDispose = handleImageDisposed;
      await tester.pumpAndSettle();
      ui.Image.onCreate = previousOnCreate;
      ui.Image.onDispose = previousOnDispose;

      expect(
        (
          steadyImagePixels <= 2 * 2048 * 2048,
          maximumLiveImagePixels <= 3 * 2048 * 2048,
          liveImagePixels,
          refreshedPixels[0],
          refreshedPixels[1],
          refreshedPixels[2],
          refreshedPixels[3],
        ),
        (
          true,
          true,
          0,
          Colors.blue.toARGB32(),
          Colors.green.toARGB32(),
          Colors.orange.toARGB32(),
          Colors.purple.toARGB32(),
        ),
      );
    },
  );

  testWidgets(
    'when snapshot pixels change several times before a watched frame, '
    'it should coalesce them into one destination capture',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      const frameKey = ValueKey<String>('watched-listenable-frame');
      final color = ValueNotifier<Color>(Colors.blue);
      addTearDown(color.dispose);
      final painter = _ListenableSnapshotPainter(color);
      var destination = false;
      late StateSetter update;
      await tester.pumpWidget(
        RepaintBoundary(
          key: frameKey,
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Align(
                    alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                    child: Morph(
                      tag: 'watched-listenable-snapshot',
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.linear,
                      watchDestination: !destination,
                      child: SizedBox(
                        key: ValueKey<bool>(destination),
                        width: destination ? 160 : 100,
                        height: destination ? 120 : 80,
                        child: Center(
                          child: MorphDescendant(
                            flightBehavior: MorphDescendantFlightBehavior.snapshot,
                            child: CustomPaint(
                              size: const Size(80, 60),
                              painter: painter,
                            ),
                          ),
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
      await tester.pumpAndSettle();

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
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
      color
        ..value = Colors.yellow
        ..value = Colors.green;
      await tester.pump();
      ui.Image.onCreate = previousOnCreate;
      await tester.pump();
      final pixel = await _pixelAt(
        tester,
        boundaryFinder: find.byKey(frameKey),
        position: tester.getCenter(_snapshotPaint),
      );

      expect(
        (imageCreations, pixel.toARGB32()),
        (1, Colors.green.toARGB32()),
      );
    },
  );

  testWidgets(
    'when nested repaint-boundary pixels change independently, '
    'it should retain automatic destination refreshes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      const frameKey = ValueKey<String>('watched-fallback-frame');
      final color = ValueNotifier<Color>(Colors.blue);
      addTearDown(color.dispose);
      final painter = _ListenableSnapshotPainter(color);
      var destination = false;
      late StateSetter update;
      await tester.pumpWidget(
        RepaintBoundary(
          key: frameKey,
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Align(
                    alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                    child: Morph(
                      tag: 'watched-fallback-snapshot',
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.linear,
                      watchDestination: !destination,
                      child: SizedBox(
                        key: ValueKey<bool>(destination),
                        width: destination ? 160 : 100,
                        height: destination ? 120 : 80,
                        child: Center(
                          child: MorphDescendant(
                            flightBehavior: MorphDescendantFlightBehavior.snapshot,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                size: const Size(80, 60),
                                painter: painter,
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      color.value = Colors.green;
      await tester.pump();
      await tester.pump();
      final pixel = await _pixelAt(
        tester,
        boundaryFinder: find.byKey(frameKey),
        position: tester.getCenter(_snapshotPaint),
      );

      expect(pixel.toARGB32(), Colors.green.toARGB32());
    },
  );

  testWidgets(
    'when unsupported watched snapshot content stays unchanged, '
    'it should not retry its completed empty capture',
    (tester) async {
      var destination = false;
      var paints = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Morph(
                tag: 'watched-unsupported-snapshot',
                duration: const Duration(milliseconds: 600),
                watchDestination: !destination,
                child: SizedBox(
                  key: ValueKey<bool>(destination),
                  width: destination ? 120 : 80,
                  height: destination ? 100 : 60,
                  child: MorphDescendant(
                    flightBehavior: MorphDescendantFlightBehavior.snapshot,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        foregroundPainter: _CountingSnapshotPainter(
                          color: Colors.transparent,
                          revision: 0,
                          onPaint: () => paints += 1,
                        ),
                        child: const Texture(textureId: 1),
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

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      paints = 0;
      for (var frame = 0; frame < 5; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(paints, 0);
    },
  );

  testWidgets(
    'when a watched flight reverses to a changed origin snapshot, '
    'it should refresh the returning geometry and pixels',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      const frameKey = ValueKey<String>('watched-reverse-frame');
      var destination = false;
      var sourceSize = const Size(40, 30);
      var sourceColor = Colors.red;
      late StateSetter update;
      await tester.pumpWidget(
        RepaintBoundary(
          key: frameKey,
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  final descendantSize = destination ? const Size(80, 60) : sourceSize;
                  return Align(
                    alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                    child: Morph(
                      tag: 'watched-reverse-snapshot',
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.linear,
                      watchDestination: true,
                      child: SizedBox(
                        key: ValueKey<bool>(destination),
                        width: descendantSize.width + 40,
                        height: descendantSize.height + 40,
                        child: Center(
                          child: MorphDescendant(
                            key: const ValueKey<String>(
                              'watched-reverse-content',
                            ),
                            flightBehavior: MorphDescendantFlightBehavior.snapshot,
                            child: SizedBox.fromSize(
                              size: descendantSize,
                              child: ColoredBox(
                                color: destination ? Colors.blue : sourceColor,
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      update(() => destination = false);
      await tester.pump();
      update(() {
        sourceSize = const Size(60, 45);
        sourceColor = Colors.green;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      final snapshotSize = tester.getSize(_snapshotPaint);
      final snapshotCenter = tester.getCenter(_snapshotPaint);
      final snapshotPixel = await _pixelAt(
        tester,
        boundaryFinder: find.byKey(frameKey),
        position: snapshotCenter,
      );

      expect(
        (snapshotSize, snapshotPixel.toARGB32()),
        (const Size(60, 45), Colors.green.toARGB32()),
      );
    },
  );

  testWidgets(
    'when a watched destination snapshot exceeds the total image budget, '
    'it should retain the coherent frame and recover when it shrinks',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(2200, 2200);
      addTearDown(() {
        tester.view
          ..resetDevicePixelRatio()
          ..resetPhysicalSize();
      });
      const frameKey = ValueKey<String>('watched-budget-frame');
      var destination = false;
      var destinationSize = const Size(80, 60);
      var destinationColor = Colors.blue;
      late StateSetter update;
      await tester.pumpWidget(
        RepaintBoundary(
          key: frameKey,
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  final descendantSize = destination ? destinationSize : const Size(40, 30);
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Morph(
                      tag: 'watched-snapshot-budget',
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.linear,
                      watchDestination: !destination,
                      child: SizedBox(
                        key: ValueKey<bool>(destination),
                        width: descendantSize.width,
                        height: descendantSize.height,
                        child: MorphDescendant(
                          flightBehavior: MorphDescendantFlightBehavior.snapshot,
                          child: CustomPaint(
                            size: descendantSize,
                            painter: _SnapshotTestPainter(
                              color: destination ? destinationColor : Colors.red,
                              throwsOnPaint: false,
                            ),
                          ),
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
      await tester.pumpAndSettle();

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
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
      update(() {
        destinationSize = const Size(2100, 2100);
        destinationColor = Colors.green;
      });
      await tester.pump();
      await tester.pump();
      final retainedSize = tester.getSize(_snapshotPaint);
      ui.Image.onCreate = previousOnCreate;
      final retainedPixel = await _pixelAt(
        tester,
        boundaryFinder: find.byKey(frameKey),
        position: tester.getCenter(_snapshotPaint),
      );

      update(() => destinationSize = const Size(120, 90));
      await tester.pump();
      await tester.pump();
      final recoveredSize = tester.getSize(_snapshotPaint);
      final recoveredPixel = await _pixelAt(
        tester,
        boundaryFinder: find.byKey(frameKey),
        position: tester.getCenter(_snapshotPaint),
      );

      expect(
        (
          imageCreations,
          retainedSize,
          retainedPixel.toARGB32(),
          recoveredSize,
          recoveredPixel.toARGB32(),
        ),
        (
          0,
          const Size(80, 60),
          Colors.blue.toARGB32(),
          const Size(120, 90),
          Colors.green.toARGB32(),
        ),
      );
    },
  );

  testWidgets(
    'when a watched fallback snapshot becomes empty, '
    'it should release the obsolete image without recapturing',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      var destination = false;
      var destinationSize = const Size(80, 60);
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                final descendantSize = destination ? destinationSize : const Size(40, 30);
                return Align(
                  alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    tag: 'watched-empty-fallback-snapshot',
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.linear,
                    watchDestination: !destination,
                    child: SizedBox(
                      key: ValueKey<bool>(destination),
                      width: 160,
                      height: 120,
                      child: Center(
                        child: MorphDescendant(
                          flightBehavior: MorphDescendantFlightBehavior.snapshot,
                          child: RepaintBoundary(
                            child: SizedBox.fromSize(
                              size: descendantSize,
                              child: const ColoredBox(color: Colors.blue),
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
        ),
      );
      await tester.pumpAndSettle();
      var imageCreations = 0;
      var liveImagePixels = 0;
      final previousOnCreate = ui.Image.onCreate;
      final previousOnDispose = ui.Image.onDispose;
      void handleImageCreated(ui.Image image) {
        previousOnCreate?.call(image);
        imageCreations += 1;
        liveImagePixels += image.width * image.height;
      }

      void handleImageDisposed(ui.Image image) {
        previousOnDispose?.call(image);
        liveImagePixels -= image.width * image.height;
      }

      ui.Image.onCreate = handleImageCreated;
      ui.Image.onDispose = handleImageDisposed;
      addTearDown(() {
        if (identical(ui.Image.onCreate, handleImageCreated)) {
          ui.Image.onCreate = previousOnCreate;
        }
        if (identical(ui.Image.onDispose, handleImageDisposed)) {
          ui.Image.onDispose = previousOnDispose;
        }
      });

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      imageCreations = 0;
      update(() => destinationSize = Size.zero);
      await tester.pump();
      await tester.pump();
      for (var frame = 0; frame < 4; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      ui.Image.onCreate = previousOnCreate;
      ui.Image.onDispose = previousOnDispose;

      expect((imageCreations, liveImagePixels), (0, 1200));
    },
  );

  testWidgets(
    'when a watched destination snapshot refresh fails, '
    'it should keep the last coherent frame and recover later',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      const frameKey = ValueKey<String>('watched-failure-frame');
      var destination = false;
      var destinationSize = const Size(80, 60);
      var destinationColor = Colors.blue;
      var throwsOnPaint = false;
      late StateSetter update;
      await tester.pumpWidget(
        RepaintBoundary(
          key: frameKey,
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  final descendantSize = destination ? destinationSize : const Size(40, 30);
                  return Align(
                    alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                    child: Morph(
                      tag: 'watched-snapshot-failure',
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.linear,
                      watchDestination: !destination,
                      child: SizedBox(
                        key: ValueKey<bool>(destination),
                        width: descendantSize.width + 40,
                        height: descendantSize.height + 40,
                        child: Center(
                          child: MorphDescendant(
                            flightBehavior: MorphDescendantFlightBehavior.snapshot,
                            child: CustomPaint(
                              size: descendantSize,
                              painter: _SnapshotTestPainter(
                                color: destination ? destinationColor : Colors.red,
                                throwsOnPaint: destination && throwsOnPaint,
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
          ),
        ),
      );
      await tester.pumpAndSettle();

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      final captureErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = captureErrors.add;
      addTearDown(() => FlutterError.onError = previousOnError);
      update(() {
        destinationSize = const Size(120, 90);
        destinationColor = Colors.green;
        throwsOnPaint = true;
      });
      await tester.pump();
      await tester.pump();
      await tester.pump();
      FlutterError.onError = previousOnError;
      final retainedSize = tester.getSize(_snapshotPaint);
      final retainedPixel = await _pixelAt(
        tester,
        boundaryFinder: find.byKey(frameKey),
        position: tester.getCenter(_snapshotPaint),
      );

      update(() => throwsOnPaint = false);
      await tester.pump();
      await tester.pump();
      final recoveredSize = tester.getSize(_snapshotPaint);
      final recoveredPixel = await _pixelAt(
        tester,
        boundaryFinder: find.byKey(frameKey),
        position: tester.getCenter(_snapshotPaint),
      );

      expect(
        (
          captureErrors.length,
          captureErrors.single.exception is StateError,
          retainedSize,
          retainedPixel.toARGB32(),
          recoveredSize,
          recoveredPixel.toARGB32(),
        ),
        (
          1,
          true,
          const Size(80, 60),
          Colors.blue.toARGB32(),
          const Size(120, 90),
          Colors.green.toARGB32(),
        ),
      );
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
