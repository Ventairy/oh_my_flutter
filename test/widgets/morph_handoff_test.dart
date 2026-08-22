import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  int flightBoundaryCount() {
    return find
        .byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_MorphFlightBoundary',
        )
        .evaluate()
        .length;
  }

  Future<Color> centerPixel(WidgetTester tester, ValueKey<String> boundaryKey, [Offset? position]) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    return (await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final x = position?.dx.toInt() ?? image.width ~/ 2;
        final y = position?.dy.toInt() ?? image.height ~/ 2;
        final offset = ((y * image.width) + x) * 4;
        return Color.fromARGB(
          bytes!.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
      } finally {
        image.dispose();
      }
    }))!;
  }

  group('Morph handoff', () {
    testWidgets(
      'when a route reaches its terminal frame, '
      'it should paint the live endpoint without an intermediate blank frame',
      (tester) async {
        const boundaryKey = ValueKey('terminal-frame-handoff-boundary');
        final sourceOffstage = ValueNotifier<bool>(false);
        final destinationOffstage = ValueNotifier<bool>(false);
        addTearDown(sourceOffstage.dispose);
        addTearDown(destinationOffstage.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: _HandoffTestApp(
              sourceOffstage: sourceOffstage,
              destinationOffstage: destinationOffstage,
              sourceChild: const MorphDescendant(
                flightBehavior: MorphDescendantFlightBehavior.hide,
                child: SizedBox.square(
                  dimension: 100,
                  child: ColoredBox(color: Colors.red),
                ),
              ),
              destinationChild: const MorphDescendant(
                flightBehavior: MorphDescendantFlightBehavior.hide,
                child: SizedBox.square(
                  dimension: 100,
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('open-destination')));
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        final terminalImage = Completer<ui.Image>();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          terminalImage.complete(await boundary.toImage());
        });
        await tester.pump(const Duration(milliseconds: 240));
        final pixel = await tester.runAsync(() async {
          final image = await terminalImage.future;
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final offset = (((image.height ~/ 2) * image.width) + image.width ~/ 2) * 4;
            return Color.fromARGB(
              bytes!.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
          } finally {
            image.dispose();
          }
        });

        expect(
          pixel,
          const Color(0xFF2196F3),
        );
      },
    );

    testWidgets(
      'when the destination cannot paint at route completion, '
      'it should retain the terminal flight until its first visible paint',
      (tester) async {
        const boundaryKey = ValueKey('paint-confirmed-handoff-boundary');
        final sourceOffstage = ValueNotifier<bool>(false);
        final destinationOffstage = ValueNotifier<bool>(true);
        final destinationColor = ValueNotifier<Color>(Colors.blue);
        addTearDown(sourceOffstage.dispose);
        addTearDown(destinationOffstage.dispose);
        addTearDown(destinationColor.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: _HandoffTestApp(
              sourceOffstage: sourceOffstage,
              destinationOffstage: destinationOffstage,
              destinationChild: ValueListenableBuilder<Color>(
                valueListenable: destinationColor,
                builder: (context, color, child) {
                  return MorphDescendant(
                    flightBehavior: MorphDescendantFlightBehavior.snapshot,
                    child: SizedBox.square(
                      dimension: 100,
                      child: ColoredBox(color: color),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('open-destination')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));
        await tester.pump();
        final retainedPixel = await centerPixel(tester, boundaryKey);
        final retainedFlightCount = flightBoundaryCount();

        destinationColor.value = Colors.green;
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        final presentedImage = Completer<ui.Image>();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          presentedImage.complete(await boundary.toImage());
        });
        destinationOffstage.value = false;
        await tester.pump();
        final handoffPixel = await tester.runAsync(() async {
          final image = await presentedImage.future;
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final offset = (((image.height ~/ 2) * image.width) + image.width ~/ 2) * 4;
            return Color.fromARGB(
              bytes!.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
          } finally {
            image.dispose();
          }
        });
        final liveImage = Completer<ui.Image>();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          liveImage.complete(await boundary.toImage());
        });
        await tester.pump();
        final presentedPixel = await tester.runAsync(() async {
          final image = await liveImage.future;
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final offset = (((image.height ~/ 2) * image.width) + image.width ~/ 2) * 4;
            return Color.fromARGB(
              bytes!.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
          } finally {
            image.dispose();
          }
        });
        await tester.pump();
        final releasedFlightCount = flightBoundaryCount();

        expect(
          (
            retainedPixel,
            retainedFlightCount,
            handoffPixel,
            presentedPixel,
            releasedFlightCount,
          ),
          (
            const Color(0xFF2196F3),
            1,
            const Color(0xFF2196F3),
            const Color(0xFF4CAF50),
            0,
          ),
        );
      },
    );

    testWidgets(
      'when a focused snapshot destination cannot paint after a route pop, '
      'it should retain its terminal pixels until the endpoint paints',
      (tester) async {
        const boundaryKey = ValueKey('route-pop-handoff-boundary');
        final navigatorKey = GlobalKey<NavigatorState>();
        final fieldKey = GlobalKey();
        final focusNode = FocusNode();
        final textController = TextEditingController(text: 'Description');
        final sourceOffstage = ValueNotifier<bool>(false);
        final destinationOffstage = ValueNotifier<bool>(false);
        addTearDown(focusNode.dispose);
        addTearDown(textController.dispose);
        addTearDown(sourceOffstage.dispose);
        addTearDown(destinationOffstage.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: _HandoffTestApp(
              navigatorKey: navigatorKey,
              sourceOffstage: sourceOffstage,
              destinationOffstage: destinationOffstage,
              sourceChild: _FocusedSnapshotSurface(
                fieldKey: fieldKey,
                focusNode: focusNode,
                textController: textController,
              ),
              destinationChild: const SizedBox.square(
                dimension: 100,
                child: ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        focusNode.requestFocus();
        await tester.pump();
        final descendantPixelPosition =
            tester
                .getRect(
                  find.byKey(
                    const ValueKey('focused-snapshot-descendant'),
                  ),
                )
                .topLeft +
            const Offset(2, 2);
        await tester.tap(find.byKey(const ValueKey('open-destination')));
        await tester.pumpAndSettle();

        sourceOffstage.value = true;
        await tester.pump();
        navigatorKey.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));
        await tester.pump();
        final retainedPixel = await centerPixel(
          tester,
          boundaryKey,
          descendantPixelPosition,
        );
        final retainedFlightCount = flightBoundaryCount();

        sourceOffstage.value = false;
        focusNode.requestFocus();
        await tester.pump();
        await tester.pump();
        await tester.pump();
        final presentedPixel = await centerPixel(
          tester,
          boundaryKey,
          descendantPixelPosition,
        );
        final releasedFlightCount = flightBoundaryCount();

        expect(
          (
            retainedPixel,
            retainedFlightCount,
            presentedPixel,
            releasedFlightCount,
            find.byKey(fieldKey).evaluate().length,
            focusNode.hasFocus,
          ),
          (
            const Color(0xFF4CAF50),
            1,
            const Color(0xFF4CAF50),
            0,
            1,
            true,
          ),
        );
      },
    );

    testWidgets(
      'when a route reverses during a pending presentation, '
      'it should cancel the stale handoff and return normally',
      (tester) async {
        const boundaryKey = ValueKey('reversed-handoff-boundary');
        final navigatorKey = GlobalKey<NavigatorState>();
        final sourceOffstage = ValueNotifier<bool>(false);
        final destinationOffstage = ValueNotifier<bool>(true);
        addTearDown(sourceOffstage.dispose);
        addTearDown(destinationOffstage.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: _HandoffTestApp(
              navigatorKey: navigatorKey,
              sourceOffstage: sourceOffstage,
              destinationOffstage: destinationOffstage,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open-destination')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));
        await tester.pump();

        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();

        expect(
          (
            await centerPixel(tester, boundaryKey),
            flightBoundaryCount(),
            tester.takeException(),
          ),
          (const Color(0xFFF44336), 0, null),
        );
      },
    );

    testWidgets(
      'when a pending destination is removed before presentation, '
      'it should release the stale flight and restore the source',
      (tester) async {
        const boundaryKey = ValueKey('removed-handoff-boundary');
        final navigatorKey = GlobalKey<NavigatorState>();
        final sourceOffstage = ValueNotifier<bool>(false);
        final destinationOffstage = ValueNotifier<bool>(true);
        addTearDown(sourceOffstage.dispose);
        addTearDown(destinationOffstage.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: _HandoffTestApp(
              navigatorKey: navigatorKey,
              sourceOffstage: sourceOffstage,
              destinationOffstage: destinationOffstage,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open-destination')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));
        await tester.pump();
        final destinationRoute = ModalRoute.of(
          tester.element(
            find.byKey(
              const ValueKey('handoff-destination'),
              skipOffstage: false,
            ),
          ),
        )!;

        navigatorKey.currentState!.removeRoute(destinationRoute);
        await tester.pumpAndSettle();

        expect(
          (
            await centerPixel(tester, boundaryKey),
            flightBoundaryCount(),
            tester.takeException(),
          ),
          (const Color(0xFFF44336), 0, null),
        );
      },
    );
  });
}

class _HandoffTestApp extends StatelessWidget {
  const _HandoffTestApp({
    required this.sourceOffstage,
    required this.destinationOffstage,
    this.navigatorKey,
    this.sourceChild = const SizedBox.square(
      dimension: 100,
      child: ColoredBox(color: Colors.red),
    ),
    this.destinationChild = const SizedBox.square(
      dimension: 100,
      child: ColoredBox(color: Colors.blue),
    ),
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final ValueNotifier<bool> sourceOffstage;
  final ValueNotifier<bool> destinationOffstage;
  final Widget sourceChild;
  final Widget destinationChild;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Stack(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: sourceOffstage,
                  builder: (context, offstage, child) {
                    return Offstage(
                      offstage: offstage,
                      child: child,
                    );
                  },
                  child: Center(
                    child: Morph(
                      key: const ValueKey('handoff-source'),
                      tag: 'paint-confirmed-handoff',
                      child: sourceChild,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: FilledButton(
                    key: const ValueKey('open-destination'),
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        PageRouteBuilder<void>(
                          opaque: false,
                          transitionDuration: const Duration(
                            milliseconds: 200,
                          ),
                          reverseTransitionDuration: const Duration(
                            milliseconds: 200,
                          ),
                          pageBuilder: (_, _, _) {
                            return ValueListenableBuilder<bool>(
                              valueListenable: destinationOffstage,
                              builder: (context, offstage, child) {
                                return Scaffold(
                                  backgroundColor: Colors.transparent,
                                  body: Offstage(
                                    offstage: offstage,
                                    child: child,
                                  ),
                                );
                              },
                              child: Center(
                                child: Morph(
                                  key: const ValueKey(
                                    'handoff-destination',
                                  ),
                                  tag: 'paint-confirmed-handoff',
                                  child: destinationChild,
                                ),
                              ),
                            );
                          },
                          transitionsBuilder: (_, _, _, child) => child,
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FocusedSnapshotSurface extends StatelessWidget {
  const _FocusedSnapshotSurface({
    required this.fieldKey,
    required this.focusNode,
    required this.textController,
  });

  final GlobalKey fieldKey;
  final FocusNode focusNode;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 100,
      child: ColoredBox(
        color: Colors.red,
        child: Align(
          alignment: Alignment.topLeft,
          child: MorphDescendant(
            key: const ValueKey('focused-snapshot-descendant'),
            flightBehavior: MorphDescendantFlightBehavior.snapshot,
            child: SizedBox(
              width: 80,
              height: 40,
              child: ColoredBox(
                color: Colors.green,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    key: fieldKey,
                    controller: textController,
                    focusNode: focusNode,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
