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

  Future<Color> nextFrameCenterPixel(
    WidgetTester tester,
    ValueKey<String> boundaryKey,
    Duration duration,
  ) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    final image = Completer<ui.Image>();
    WidgetsBinding.instance.addPostFrameCallback((_) => image.complete(boundary.toImageSync()));
    await tester.pump(duration);
    return (await tester.runAsync(() async {
      final frame = await image.future;
      try {
        final bytes = await frame.toByteData(format: ui.ImageByteFormat.rawRgba);
        final offset = (((frame.height ~/ 2) * frame.width) + frame.width ~/ 2) * 4;
        return Color.fromARGB(
          bytes!.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
      } finally {
        frame.dispose();
      }
    }))!;
  }

  group('Morph handoff', () {
    testWidgets(
      'when an independently timed flight reaches its terminal frame, '
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
              morphDuration: const Duration(milliseconds: 400),
              sourceChild: const MorphDescendant(
                flightBehavior: MorphDescendantFlightBehavior.hide(),
                child: SizedBox.square(
                  dimension: 100,
                  child: ColoredBox(color: Colors.red),
                ),
              ),
              destinationChild: const MorphDescendant(
                flightBehavior: MorphDescendantFlightBehavior.hide(),
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
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        final terminalImage = Completer<ui.Image>();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          terminalImage.complete(await boundary.toImage());
        });
        await tester.pump(const Duration(milliseconds: 440));
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
                    flightBehavior: const MorphDescendantFlightBehavior.snapshot(),
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
      'when a route pop hands off a translucent shadow, '
      'it should match the settled single-layer pixels',
      (tester) async {
        const boundaryKey = ValueKey('translucent-pop-handoff-boundary');
        const sourceSurfaceKey = ValueKey('translucent-pop-source');
        final navigatorKey = GlobalKey<NavigatorState>();
        final sourceOffstage = ValueNotifier<bool>(false);
        final destinationOffstage = ValueNotifier<bool>(false);
        addTearDown(sourceOffstage.dispose);
        addTearDown(destinationOffstage.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: _HandoffTestApp(
              navigatorKey: navigatorKey,
              sourceOffstage: sourceOffstage,
              destinationOffstage: destinationOffstage,
              sourceChild: Container(
                key: sourceSurfaceKey,
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 0,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
              destinationChild: const SizedBox.square(
                dimension: 100,
                child: ColoredBox(color: Colors.green),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open-destination')));
        await tester.pumpAndSettle();

        navigatorKey.currentState!.pop();
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        final sourceRect = tester.getRect(find.byKey(sourceSurfaceKey));
        final samplePosition = Offset(
          sourceRect.right + 5,
          sourceRect.center.dy,
        );
        final handoffImage = Completer<ui.Image>();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          handoffImage.complete(await boundary.toImage());
        });
        await tester.pump(const Duration(milliseconds: 240));
        final handoffPixel = await tester.runAsync(() async {
          final image = await handoffImage.future;
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final offset = ((samplePosition.dy.toInt() * image.width) + samplePosition.dx.toInt()) * 4;
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
        await tester.pumpAndSettle();
        final settledPixel = await centerPixel(
          tester,
          boundaryKey,
          samplePosition,
        );

        expect(handoffPixel, settledPixel);
      },
    );

    testWidgets(
      'when a watched grouped route pop hands off with a nested flight, '
      'it should keep the destination content visible until the overlay is removed',
      (tester) async {
        tester.view
          ..physicalSize = const Size(300, 300)
          ..devicePixelRatio = 1;
        addTearDown(() {
          tester.view
            ..resetPhysicalSize()
            ..resetDevicePixelRatio();
        });
        const boundaryKey = ValueKey('watched-group-pop-handoff-boundary');
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: _WatchedGroupPopHandoffApp(navigatorKey: navigatorKey),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open-watched-group-destination')));
        await tester.pumpAndSettle();

        navigatorKey.currentState!.pop();
        await tester.pump();
        final transitionPixels = <Color>[];
        for (var elapsed = 0; elapsed < 272; elapsed += 16) {
          final pixel = await nextFrameCenterPixel(
            tester,
            boundaryKey,
            const Duration(milliseconds: 16),
          );
          transitionPixels.add(pixel);
        }
        await tester.pumpAndSettle();

        expect(
          transitionPixels,
          everyElement(isNot(const Color(0xFFFFFFFF))),
          reason: 'A nested cohort flight must cover the watched parent until both handoffs are ready.',
        );
        expect(transitionPixels.last, const Color(0xFF4CAF50));
        expect(flightBoundaryCount(), 0);
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
      'when a route-driven push reverses after destination presentation but before handoff release, '
      'it should restore exclusive flight paint ownership',
      (tester) async {
        tester.view
          ..physicalSize = const Size(300, 300)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const boundaryKey = ValueKey('presented-reversal-handoff-boundary');
        MorphFlight<Color>? activeFlight;
        final flightDelegate = _HandoffColorFlightDelegate(
          const Color(0xFF2196F3),
          (flight) => activeFlight = flight,
        );
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
              routeDuration: const Duration(milliseconds: 400),
              sourceFlightDelegate: flightDelegate,
              destinationFlightDelegate: flightDelegate,
              destinationChild: const SizedBox.expand(
                child: ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('open-destination')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 440));
        expect(flightBoundaryCount(), greaterThan(0));

        destinationOffstage.value = false;
        navigatorKey.currentState!.pop();
        const probe = Offset(2, 290);
        var observedUncoveredFlightPixel = false;
        for (var elapsed = 16; elapsed <= 192; elapsed += 16) {
          await tester.pump(const Duration(milliseconds: 16));
          if (activeFlight!.bounds.contains(probe)) continue;
          observedUncoveredFlightPixel = true;
          expect(
            await centerPixel(tester, boundaryKey, probe),
            Colors.white,
            reason: 'The live destination must hide again while its existing flight reverses.',
          );
          break;
        }
        expect(
          observedUncoveredFlightPixel,
          isTrue,
          reason: 'The probe must leave the reversing overlay before the route pop completes.',
        );
        await tester.pumpAndSettle();
        expect(
          (flightBoundaryCount(), tester.takeException()),
          (0, null),
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

class _HandoffTestApp extends StatefulWidget {
  const new({
    required this.sourceOffstage,
    required this.destinationOffstage,
    this.navigatorKey,
    this.morphDuration,
    this.routeDuration = const Duration(milliseconds: 200),
    this.sourceFlightDelegate,
    this.destinationFlightDelegate,
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
  final Duration? morphDuration;
  final Duration routeDuration;
  final MorphFlightDelegate<Color>? sourceFlightDelegate;
  final MorphFlightDelegate<Color>? destinationFlightDelegate;
  final ValueNotifier<bool> sourceOffstage;
  final ValueNotifier<bool> destinationOffstage;
  final Widget sourceChild;
  final Widget destinationChild;

  @override
  State<_HandoffTestApp> createState() => _HandoffTestAppState();
}

class _HandoffTestAppState extends State<_HandoffTestApp> {
  late final _morphTarget1 = MorphTarget(
    tag: 'paint-confirmed-handoff',
    duration: widget.morphDuration,
  );

  final _morphObserver1 = MorphNavigatorObserver();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [_morphObserver1],
      navigatorKey: widget.navigatorKey,
      home: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Stack(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: widget.sourceOffstage,
                  builder: (context, offstage, child) {
                    return Offstage(
                      offstage: offstage,
                      child: child,
                    );
                  },
                  child: Center(
                    child: Morph(
                      key: const ValueKey('handoff-source'),
                      targets: [_morphTarget1],
                      flightConfig: widget.sourceFlightDelegate == null
                          ? const .auto()
                          : .custom(widget.sourceFlightDelegate!),

                      child: widget.sourceChild,
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
                          transitionDuration: widget.routeDuration,
                          reverseTransitionDuration: widget.routeDuration,
                          pageBuilder: (_, _, _) {
                            return ValueListenableBuilder<bool>(
                              valueListenable: widget.destinationOffstage,
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
                                  targets: [_morphTarget1],
                                  flightConfig: widget.destinationFlightDelegate == null
                                      ? const .auto()
                                      : .custom(widget.destinationFlightDelegate!),

                                  child: widget.destinationChild,
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

final class _HandoffColorFlightDelegate extends MorphFlightDelegate<Color> {
  const new(this.color, this.onFlightBuilt);

  final Color color;
  final ValueChanged<MorphFlight<Color>> onFlightBuilt;

  @override
  Color properties(MorphEndpointContext endpoint) => color;

  @override
  Color lerpProperties(Color source, Color destination, MorphFlightProgress progress) =>
      Color.lerp(source, destination, progress.curvedProgress)!;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<Color> flight) {
    onFlightBuilt(flight);
    return AnimatedBuilder(
      animation: flight.curvedAnimation,
      builder: (context, child) => ColoredBox(color: flight.properties),
    );
  }
}

class _FocusedSnapshotSurface extends StatelessWidget {
  const new({
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
            flightBehavior: const MorphDescendantFlightBehavior.snapshot(),
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

class _WatchedGroupPopHandoffApp extends StatefulWidget {
  const new({required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<_WatchedGroupPopHandoffApp> createState() => _WatchedGroupPopHandoffAppState();
}

class _WatchedGroupPopHandoffAppState extends State<_WatchedGroupPopHandoffApp> {
  final _surfaceTarget = MorphTarget(
    tag: 'watched-group-pop-surface',
    watchDestination: true,
  );
  final _headerTarget = MorphTarget(tag: 'watched-group-pop-header');
  final _sourceGroup = GroupLink();
  final _destinationGroup = GroupLink();
  final _observer = MorphNavigatorObserver();

  Widget _endpoint({required bool destination}) {
    final group = destination ? _destinationGroup : _sourceGroup;
    return SizedBox.square(
      dimension: destination ? 300 : 240,
      child: Morph(
        targets: [_surfaceTarget],
        flightConfig: .custom(_WatchedGroupPopDelegate(group)),
        child: ColoredBox(
          color: Colors.white,
          child: Group(
            link: group,
            child: Morph(
              targets: [_headerTarget],
              child: ColoredBox(
                color: destination ? Colors.green : Colors.blue,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      navigatorObservers: [_observer],
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              _endpoint(destination: true),
              Positioned(
                top: 8,
                child: FilledButton(
                  key: const ValueKey('open-watched-group-destination'),
                  onPressed: () {
                    widget.navigatorKey.currentState!.push<void>(
                      PageRouteBuilder<void>(
                        opaque: false,
                        barrierColor: const Color(0x1F000000),
                        transitionDuration: const Duration(milliseconds: 200),
                        reverseTransitionDuration: const Duration(milliseconds: 200),
                        pageBuilder: (_, _, _) => Scaffold(
                          backgroundColor: Colors.transparent,
                          body: Center(child: _endpoint(destination: false)),
                        ),
                        transitionsBuilder: (_, _, _, child) => child,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _WatchedGroupPopDelegate extends MorphFlightDelegate<Widget> {
  const new(this.group);

  final GroupLink group;

  @override
  Iterable<GroupLink> get contentGroups => [group];

  @override
  Widget properties(MorphEndpointContext endpoint) => endpoint.groupSnapshot(group);

  @override
  Widget lerpProperties(Widget source, Widget destination, MorphFlightProgress progress) =>
      progress.curvedProgress < .5 ? source : destination;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<Widget> flight) {
    return ColoredBox(
      color: Colors.white,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.fill,
          child: flight.destination.properties,
        ),
      ),
    );
  }
}
