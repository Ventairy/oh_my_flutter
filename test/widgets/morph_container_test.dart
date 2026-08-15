import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Finder _morphOverlay() {
  return find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_MorphOverlay',
  );
}

Text _flightText(WidgetTester tester, String text) {
  final finder = find.descendant(
    of: _morphOverlay(),
    matching: find.text(text, skipOffstage: false),
  );
  if (finder.evaluate().isNotEmpty) return tester.widget<Text>(finder);

  final layout = _retainedTextLayouts(
    tester,
  ).singleWhere((layout) => layout['text'] == text);
  return Text(
    layout['text']! as String,
    style: layout['style']! as TextStyle,
    textDirection: layout['textDirection']! as TextDirection,
    textScaler: layout['textScaler']! as TextScaler,
    maxLines: layout['maxLines'] as int?,
    overflow: layout['overflow'] as TextOverflow?,
  );
}

List<Map<String, Object?>> _retainedTextLayouts(WidgetTester tester) {
  final renderObject = tester.renderObject<RenderBox>(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_MorphCompoundFlight',
    ),
  );
  final property = renderObject.toDiagnosticsNode().getProperties().singleWhere(
    (property) => property.name == 'retainedTextLayouts',
  );
  return (property.value! as List<Object?>).cast<Map<String, Object?>>();
}

int _retainedDecorationInterpolationsAtProgress(WidgetTester tester) {
  final renderObject = tester.renderObject<RenderBox>(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_MorphCompoundFlight',
    ),
  );
  return renderObject
          .toDiagnosticsNode()
          .getProperties()
          .singleWhere(
            (property) => property.name == 'retainedDecorationInterpolationsAtProgress',
          )
          .value!
      as int;
}

int _flightTextCount(WidgetTester tester, String text) {
  final widgetCount = find
      .descendant(
        of: _morphOverlay(),
        matching: find.text(text, skipOffstage: false),
      )
      .evaluate()
      .length;
  if (widgetCount != 0) return widgetCount;
  return _retainedTextLayouts(
    tester,
  ).where((layout) => layout['text'] == text).length;
}

Future<({int height, List<int> pixels, int width})> _capturePixels(
  WidgetTester tester,
  Key boundaryKey,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (
        height: image.height,
        pixels: List<int>.generate(
          bytes!.lengthInBytes,
          bytes.getUint8,
          growable: false,
        ),
        width: image.width,
      );
    } finally {
      image.dispose();
    }
  }))!;
}

int _redPixelCount(
  ({int height, List<int> pixels, int width}) frame,
  Rect region,
) {
  final left = region.left.floor().clamp(0, frame.width);
  final top = region.top.floor().clamp(0, frame.height);
  final right = region.right.ceil().clamp(0, frame.width);
  final bottom = region.bottom.ceil().clamp(0, frame.height);
  var count = 0;
  for (var y = top; y < bottom; y += 1) {
    for (var x = left; x < right; x += 1) {
      final offset = (y * frame.width + x) * 4;
      final red = frame.pixels[offset];
      final green = frame.pixels[offset + 1];
      final blue = frame.pixels[offset + 2];
      final alpha = frame.pixels[offset + 3];
      if (alpha != 0 && red > green + 40 && red > blue + 40) {
        count += 1;
      }
    }
  }
  return count;
}

bool _pixelsMatch(
  ({int height, List<int> pixels, int width}) source,
  ({int height, List<int> pixels, int width}) destination,
  Rect region,
) {
  if (source.width != destination.width || source.height != destination.height) {
    return false;
  }
  final left = region.left.floor().clamp(0, source.width);
  final top = region.top.floor().clamp(0, source.height);
  final right = region.right.ceil().clamp(0, source.width);
  final bottom = region.bottom.ceil().clamp(0, source.height);
  for (var y = top; y < bottom; y += 1) {
    for (var x = left; x < right; x += 1) {
      final offset = (y * source.width + x) * 4;
      for (var channel = 0; channel < 4; channel += 1) {
        if (source.pixels[offset + channel] != destination.pixels[offset + channel]) {
          return false;
        }
      }
    }
  }
  return true;
}

bool _pixelRegionsMatch(
  ({int height, List<int> pixels, int width}) frame,
  Rect first,
  Rect second,
) {
  final firstLeft = first.left.round();
  final firstTop = first.top.round();
  final secondLeft = second.left.round();
  final secondTop = second.top.round();
  final width = first.width.round();
  final height = first.height.round();
  if (width != second.width.round() || height != second.height.round()) {
    return false;
  }
  for (var y = 0; y < height; y += 1) {
    for (var x = 0; x < width; x += 1) {
      final firstOffset = ((firstTop + y) * frame.width + firstLeft + x) * 4;
      final secondOffset = ((secondTop + y) * frame.width + secondLeft + x) * 4;
      for (var channel = 0; channel < 4; channel += 1) {
        if (frame.pixels[firstOffset + channel] != frame.pixels[secondOffset + channel]) {
          return false;
        }
      }
    }
  }
  return true;
}

final class _ExtremeOvershootCurve extends Curve {
  const _ExtremeOvershootCurve();

  @override
  double transformInternal(double t) {
    final secondHarmonic = 4 - 0.6 * math.sqrt(0.5);
    return t - 0.6 * math.sin(math.pi * t) + secondHarmonic * math.sin(2 * math.pi * t);
  }
}

void main() {
  group('Morph Container', () {
    test('when no curve is provided, it should defer curve resolution', () {
      final morph = Morph(tag: 'default-curve', child: Container());

      expect(morph.curve, isNull);
    });

    testWidgets(
      'when building at rest, it should preserve the original decoration',
      (tester) async {
        const decoration = BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Morph(
                tag: 'decorated',
                child: Container(
                  key: const ValueKey('decorated'),
                  width: 200,
                  height: 100,
                  decoration: decoration,
                ),
              ),
            ),
          ),
        );

        expect(
          tester.widget<Container>(find.byKey(const ValueKey('decorated'))).decoration,
          decoration,
        );
      },
    );

    testWidgets(
      'when building at rest, it should preserve the original child',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Morph(
                tag: 'child',
                child: Container(
                  width: 200,
                  height: 100,
                  color: Colors.red,
                  child: const Text('Container child'),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Container child'), findsOneWidget);
      },
    );

    testWidgets(
      'when building at rest, it should preserve padding',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Morph(
                tag: 'padded',
                child: Container(
                  key: const ValueKey('padded'),
                  padding: const EdgeInsets.all(24),
                  child: const Text('Padded'),
                ),
              ),
            ),
          ),
        );

        expect(
          tester.widget<Container>(find.byKey(const ValueKey('padded'))).padding,
          const EdgeInsets.all(24),
        );
      },
    );

    testWidgets(
      'when building at rest, it should preserve explicit width',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Morph(
                tag: 'sized',
                child: Container(
                  key: const ValueKey('sized'),
                  width: 300,
                  height: 80,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        );

        expect(tester.getSize(find.byKey(const ValueKey('sized'))).width, 300);
      },
    );

    testWidgets(
      'when box properties change, it should settle with the destination decoration',
      (tester) async {
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Center(
                  child: Morph(
                    tag: 'container',
                    child: Container(
                      width: destination ? 160 : 80,
                      height: destination ? 120 : 80,
                      padding: EdgeInsets.all(destination ? 24 : 8),
                      decoration: BoxDecoration(
                        color: destination ? Colors.blue : Colors.red,
                        borderRadius: BorderRadius.circular(
                          destination ? 32 : 8,
                        ),
                      ),
                      child: Text(destination ? 'Destination' : 'Source'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        update(() => destination = true);
        await tester.pumpAndSettle();

        final container = tester.widget<Container>(find.byType(Container).last);
        expect(
          (container.constraints?.minWidth, container.constraints?.minHeight),
          (160, 120),
        );
      },
    );

    testWidgets(
      'when retained paint bounds and paint share one progress, it should interpolate each decoration once',
      (tester) async {
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Center(
                  child: Morph(
                    tag: 'cached-decoration',
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.linear,
                    child: Container(
                      key: ValueKey('cached-decoration-$destination'),
                      width: 140,
                      height: 100,
                      decoration: BoxDecoration(
                        color: destination ? Colors.blue : Colors.red,
                        borderRadius: BorderRadius.circular(destination ? 28 : 8),
                      ),
                      foregroundDecoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: destination
                              ? const <Color>[Colors.green, Colors.blue]
                              : const <Color>[Colors.orange, Colors.purple],
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
        await tester.pump(const Duration(milliseconds: 120));
        final renderObject = tester.renderObject<RenderBox>(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphCompoundFlight',
          ),
        );
        for (var read = 0; read < 3; read += 1) {
          renderObject.paintBounds;
        }

        expect(_retainedDecorationInterpolationsAtProgress(tester), 2);
      },
    );

    testWidgets(
      'when retained compound endpoint values are equal, it should skip static interpolation',
      (tester) async {
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Center(
                  child: Morph(
                    tag: 'static-compound',
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.linear,
                    child: Container(
                      key: ValueKey('static-compound-$destination'),
                      width: 160,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      foregroundDecoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[Colors.orange, Colors.purple],
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Static compound',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
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

        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final layout = _retainedTextLayouts(tester).singleWhere(
          (layout) => layout['text'] == 'Static compound',
        );

        expect(
          (
            decorations: _retainedDecorationInterpolationsAtProgress(tester),
            padding: layout['paddingIsStatic'],
            rect: layout['rectIsStatic'],
            text: layout['interpolationsAtProgress'],
          ),
          (decorations: 0, padding: true, rect: true, text: 0),
        );
      },
    );

    testWidgets(
      'when retained gradients and blurred shadows paint directly, they should match BoxDecoration pixels',
      (tester) async {
        tester.view.physicalSize = const Size(520, 260);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final previousDebugDisableShadows = debugDisableShadows;
        debugDisableShadows = false;
        addTearDown(() => debugDisableShadows = previousDebugDisableShadows);
        const boundaryKey = ValueKey('direct-decoration-boundary');
        const referenceKey = ValueKey('direct-decoration-reference');
        const sourceDecoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFE83B64), Color(0xFFFFC857)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(10)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x66000000),
              offset: Offset(8, 6),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        );
        const destinationDecoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: <Color>[Color(0xFF2557D6), Color(0xFF2DD4A7)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(30)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x88002060),
              offset: Offset(-4, 10),
              blurRadius: 18,
              spreadRadius: 5,
            ),
          ],
        );
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                backgroundColor: Colors.white,
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Positioned(
                          left: 80,
                          top: 90,
                          child: Morph(
                            tag: 'direct-decoration',
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.linear,
                            child: Container(
                              key: ValueKey('direct-decoration-$destination'),
                              width: 100,
                              height: 70,
                              decoration: destination ? destinationDecoration : sourceDecoration,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 320,
                          top: 90,
                          child: DecoratedBox(
                            key: referenceKey,
                            decoration: destination
                                ? BoxDecoration.lerp(
                                    sourceDecoration,
                                    destinationDecoration,
                                    0.5,
                                  )!
                                : sourceDecoration,
                            child: const SizedBox(width: 100, height: 70),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundaryBounds = tester.getRect(find.byKey(boundaryKey));
        final sourceBounds = tester.getRect(
          find.byKey(const ValueKey('direct-decoration-false')),
        );
        final referenceBounds = tester.getRect(find.byKey(referenceKey));

        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final frame = await _capturePixels(tester, boundaryKey);
        final sourceRegion = sourceBounds.inflate(44).shift(-boundaryBounds.topLeft);
        final referenceRegion = referenceBounds.inflate(44).shift(-boundaryBounds.topLeft);
        debugDisableShadows = previousDebugDisableShadows;

        expect(
          (
            _morphOverlay().evaluate().length,
            _pixelRegionsMatch(frame, sourceRegion, referenceRegion),
          ),
          (1, true),
        );
      },
    );

    testWidgets(
      'when debug shadows are disabled, direct outer shadows should match BoxDecoration pixels',
      (tester) async {
        tester.view.physicalSize = const Size(520, 260);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final previousDebugDisableShadows = debugDisableShadows;
        debugDisableShadows = true;
        addTearDown(() => debugDisableShadows = previousDebugDisableShadows);
        const boundaryKey = ValueKey('disabled-shadow-boundary');
        const referenceKey = ValueKey('disabled-shadow-reference');
        const sourceDecoration = BoxDecoration(
          color: Color(0xFFE83B64),
          borderRadius: BorderRadius.all(Radius.circular(12)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0xFF7D2AE8),
              offset: Offset(7, 5),
              blurRadius: 14,
              spreadRadius: 4,
              blurStyle: BlurStyle.outer,
            ),
          ],
        );
        const destinationDecoration = BoxDecoration(
          color: Color(0xFF2557D6),
          borderRadius: BorderRadius.all(Radius.circular(28)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(0xFF1FAD7A),
              offset: Offset(-3, 9),
              blurRadius: 20,
              spreadRadius: 6,
              blurStyle: BlurStyle.outer,
            ),
          ],
        );
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                backgroundColor: Colors.white,
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Positioned(
                          left: 80,
                          top: 90,
                          child: Morph(
                            tag: 'disabled-shadow',
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.linear,
                            child: Container(
                              key: ValueKey('disabled-shadow-$destination'),
                              width: 100,
                              height: 70,
                              decoration: destination ? destinationDecoration : sourceDecoration,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 320,
                          top: 90,
                          child: DecoratedBox(
                            key: referenceKey,
                            decoration: destination
                                ? BoxDecoration.lerp(
                                    sourceDecoration,
                                    destinationDecoration,
                                    0.5,
                                  )!
                                : sourceDecoration,
                            child: const SizedBox(width: 100, height: 70),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundaryBounds = tester.getRect(find.byKey(boundaryKey));
        final sourceBounds = tester.getRect(
          find.byKey(const ValueKey('disabled-shadow-false')),
        );
        final referenceBounds = tester.getRect(find.byKey(referenceKey));

        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final frame = await _capturePixels(tester, boundaryKey);
        final sourceRegion = sourceBounds.inflate(44).shift(-boundaryBounds.topLeft);
        final referenceRegion = referenceBounds.inflate(44).shift(-boundaryBounds.topLeft);

        expect(
          (
            _morphOverlay().evaluate().length,
            _pixelRegionsMatch(frame, sourceRegion, referenceRegion),
          ),
          (1, true),
        );
      },
    );

    testWidgets(
      'when a container transfer settles, it should invoke source and receiving callbacks in order',
      (tester) async {
        var destination = false;
        late StateSetter update;
        final events = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Center(
                  child: Morph(
                    tag: 'container-lifecycle',
                    onStart: destination ? () => events.add('destination-start') : () => events.add('source-start'),
                    onEnd: destination ? () => events.add('destination-end') : () => events.add('source-end'),
                    onReceived: destination
                        ? () => events.add('destination-received')
                        : () => events.add('source-received'),
                    child: Container(
                      key: ValueKey(destination),
                      width: destination ? 160 : 80,
                      height: destination ? 120 : 80,
                      color: destination ? Colors.blue : Colors.red,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        update(() => destination = true);
        await tester.pumpAndSettle();

        expect(
          events,
          ['source-start', 'destination-received', 'source-end'],
        );
      },
    );

    testWidgets(
      'when supported compound children are nested, it should interpolate without an exception',
      (tester) async {
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Center(
                  child: Morph(
                    tag: 'nested-container',
                    child: Container(
                      width: destination ? 220 : 120,
                      padding: EdgeInsets.all(destination ? 20 : 8),
                      color: destination ? Colors.blue : Colors.red,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(destination ? 'Destination' : 'Source'),
                          Container(
                            width: destination ? 80 : 40,
                            height: 20,
                            color: destination ? Colors.white : Colors.black,
                          ),
                        ],
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
        await tester.pump(const Duration(milliseconds: 150));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when an unsupported child flies from a local theme, it should preserve the endpoint theme',
      (tester) async {
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              textTheme: const TextTheme(
                bodyMedium: TextStyle(color: Colors.black),
              ),
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return DefaultTextStyle(
                    style: const TextStyle(color: Colors.red),
                    child: Align(
                      alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                      child: Morph(
                        tag: 'inherited-flight-theme',
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.linear,
                        child: Container(
                          key: ValueKey(destination),
                          width: destination ? 180 : 120,
                          height: destination ? 100 : 80,
                          color: Colors.white,
                          child: const ColoredBox(
                            color: Colors.transparent,
                            child: ClipRect(
                              child: Text(
                                'Inherited flight theme',
                                overflow: TextOverflow.clip,
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
        await tester.pump(const Duration(milliseconds: 100));
        final flightText = find.descendant(
          of: _morphOverlay(),
          matching: find.text('Inherited flight theme'),
        );
        final inheritedColor = DefaultTextStyle.of(
          tester.element(flightText),
        ).style.color;

        expect(
          (
            _morphOverlay().evaluate().length,
            find
                .descendant(
                  of: _morphOverlay(),
                  matching: find.byWidgetPredicate(
                    (widget) => widget.runtimeType.toString() == '_MorphHybridContainerFlight',
                  ),
                )
                .evaluate()
                .length,
            inheritedColor,
          ),
          (1, 1, Colors.red),
        );
      },
    );

    testWidgets(
      'when overlay insets change during a raw child flight, it should preserve the endpoint SafeArea geometry',
      (tester) async {
        var destination = false;
        var overlayBottomPadding = 0.0;
        var overlayBottomInset = 300.0;
        late StateSetter update;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MaterialApp(
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: EdgeInsets.only(
                        bottom: overlayBottomPadding,
                      ),
                      viewInsets: EdgeInsets.only(
                        bottom: overlayBottomInset,
                      ),
                    ),
                    child: child!,
                  );
                },
                home: Scaffold(
                  body: MediaQuery(
                    data: const MediaQueryData(
                      padding: EdgeInsets.only(bottom: 24),
                      viewInsets: EdgeInsets.zero,
                    ),
                    child: Align(
                      alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                      child: Morph(
                        tag: 'captured-safe-area',
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.linear,
                        child: Container(
                          key: ValueKey('safe-area-surface-$destination'),
                          width: 180,
                          height: 120,
                          color: Colors.white,
                          child: const SafeArea(
                            top: false,
                            child: SizedBox(
                              key: ValueKey('captured-safe-area-content'),
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
        );
        await tester.pumpAndSettle();

        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final rawSlot = find.descendant(
          of: _morphOverlay(),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphHybridRawSlot',
          ),
        );
        final flightContent = find.descendant(
          of: _morphOverlay(),
          matching: find.byKey(
            const ValueKey('captured-safe-area-content'),
          ),
        );
        double contentBottomInsetWithinFlight() {
          return tester.getBottomRight(rawSlot).dy - tester.getBottomRight(flightContent).dy;
        }

        final beforeOverlayChange = contentBottomInsetWithinFlight();
        update(() {
          overlayBottomPadding = 72;
          overlayBottomInset = 0;
        });
        await tester.pump();
        final afterOverlayChange = contentBottomInsetWithinFlight();

        expect(
          (beforeOverlayChange, afterOverlayChange),
          (24, 24),
        );
      },
    );

    testWidgets(
      'when raw endpoints have different MediaQuery data, it should switch SafeArea geometry with child ownership',
      (tester) async {
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: [
                      if (!destination)
                        MediaQuery(
                          key: const ValueKey('source-media-query'),
                          data: const MediaQueryData(
                            padding: EdgeInsets.only(top: 12),
                          ),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Morph(
                              tag: 'different-safe-areas',
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.linear,
                              child: Container(
                                key: const ValueKey('source-safe-area-surface'),
                                width: 160,
                                height: 100,
                                color: Colors.red,
                                child: const SafeArea(
                                  bottom: false,
                                  child: SizedBox(
                                    key: ValueKey('source-safe-area-content'),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        MediaQuery(
                          key: const ValueKey('destination-media-query'),
                          data: const MediaQueryData(
                            padding: EdgeInsets.only(top: 44),
                          ),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Morph(
                              tag: 'different-safe-areas',
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.linear,
                              child: Container(
                                key: const ValueKey(
                                  'destination-safe-area-surface',
                                ),
                                width: 220,
                                height: 140,
                                color: Colors.blue,
                                child: const SafeArea(
                                  bottom: false,
                                  child: SizedBox(
                                    key: ValueKey(
                                      'destination-safe-area-content',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
        await tester.pump(const Duration(milliseconds: 100));
        final rawSlot = find.descendant(
          of: _morphOverlay(),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphHybridRawSlot',
          ),
        );
        double contentTopWithinFlight(Finder content) {
          return tester.getTopLeft(content).dy - tester.getTopLeft(rawSlot).dy;
        }

        final sourceTop = contentTopWithinFlight(
          find.descendant(
            of: _morphOverlay(),
            matching: find.byKey(
              const ValueKey('source-safe-area-content'),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        final destinationTop = contentTopWithinFlight(
          find.descendant(
            of: _morphOverlay(),
            matching: find.byKey(
              const ValueKey('destination-safe-area-content'),
            ),
          ),
        );

        expect((sourceTop, destinationTop), (12, 44));
      },
    );

    testWidgets(
      'when ordinary descendants use a transition, it should animate them out and in around ownership',
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
                      tag: 'ordinary-transition',
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.linear,
                      nonMorphDescendantsTransition: (child, animation) {
                        return FadeTransition(
                          key: const ValueKey(
                            'ordinary-content-transition',
                          ),
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: Container(
                        key: ValueKey('transition-surface-$destination'),
                        width: destination ? 220 : 140,
                        height: destination ? 160 : 100,
                        color: destination ? Colors.blue : Colors.red,
                        child: SafeArea(
                          child: SizedBox(
                            key: ValueKey(
                              destination ? 'arriving-ordinary-content' : 'departing-ordinary-content',
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
        await tester.pump(const Duration(milliseconds: 100));
        final departingOpacity = tester
            .widget<FadeTransition>(
              find.descendant(
                of: _morphOverlay(),
                matching: find.byKey(
                  const ValueKey('ordinary-content-transition'),
                ),
              ),
            )
            .opacity
            .value;
        final departingVisible = find
            .descendant(
              of: _morphOverlay(),
              matching: find.byKey(
                const ValueKey('departing-ordinary-content'),
              ),
            )
            .evaluate()
            .length;

        await tester.pump(const Duration(milliseconds: 200));
        final arrivingOpacity = tester
            .widget<FadeTransition>(
              find.descendant(
                of: _morphOverlay(),
                matching: find.byKey(
                  const ValueKey('ordinary-content-transition'),
                ),
              ),
            )
            .opacity
            .value;
        final arrivingVisible = find
            .descendant(
              of: _morphOverlay(),
              matching: find.byKey(
                const ValueKey('arriving-ordinary-content'),
              ),
            )
            .evaluate()
            .length;
        final hybridFlightCount = find
            .descendant(
              of: _morphOverlay(),
              matching: find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_MorphHybridContainerFlight',
              ),
            )
            .evaluate()
            .length;
        final positionedFlightCount = find
            .descendant(
              of: _morphOverlay(),
              matching: find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_MorphPositionedFlight',
              ),
            )
            .evaluate()
            .length;

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(
          (
            (departingOpacity - 0.5).abs() < 1e-9,
            departingVisible,
            (arrivingOpacity - 0.5).abs() < 1e-9,
            arrivingVisible,
            hybridFlightCount,
            positionedFlightCount,
            _morphOverlay().evaluate().length,
            find
                .byKey(
                  const ValueKey('arriving-ordinary-content'),
                )
                .evaluate()
                .length,
          ),
          (true, 1, true, 1, 0, 1, 0, 1),
        );
      },
    );

    testWidgets(
      'when an ordinary descendant remains selected, it should retain its transition subtree between flight frames',
      (tester) async {
        var destination = false;
        var transitionBuilds = 0;
        var rawBuilds = 0;
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
                      tag: 'retained-ordinary-transition',
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.linear,
                      nonMorphDescendantsTransition: (child, animation) {
                        transitionBuilds += 1;
                        return FadeTransition(
                          key: const ValueKey(
                            'retained-ordinary-transition-flight',
                          ),
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: Container(
                        key: ValueKey('retained-transition-$destination'),
                        width: destination ? 220 : 140,
                        height: destination ? 160 : 100,
                        color: destination ? Colors.blue : Colors.red,
                        child: Builder(
                          key: ValueKey(
                            destination ? 'retained-arriving-child' : 'retained-departing-child',
                          ),
                          builder: (context) {
                            rawBuilds += 1;
                            return const SizedBox.expand();
                          },
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
        final buildsAtStart = transitionBuilds;
        final rawBuildsAtStart = rawBuilds;
        await tester.pump(const Duration(milliseconds: 40));
        await tester.pump(const Duration(milliseconds: 40));
        final buildsBeforeSwitch = transitionBuilds;
        final rawBuildsBeforeSwitch = rawBuilds;
        final transition = find.descendant(
          of: _morphOverlay(),
          matching: find.byKey(
            const ValueKey('retained-ordinary-transition-flight'),
          ),
        );
        final retainedBoundaryCount = find
            .descendant(
              of: transition,
              matching: find.byType(RepaintBoundary),
            )
            .evaluate()
            .length;
        final transitionIsRepaintBoundary = tester.renderObject<RenderAnimatedOpacity>(transition).isRepaintBoundary;
        await tester.pump(const Duration(milliseconds: 160));
        final buildsAfterSwitch = transitionBuilds;
        final rawBuildsAfterSwitch = rawBuilds;

        expect(
          (
            buildsAtStart > 0,
            buildsBeforeSwitch == buildsAtStart,
            buildsAfterSwitch == buildsAtStart + 1,
            retainedBoundaryCount,
            transitionIsRepaintBoundary,
            rawBuildsBeforeSwitch == rawBuildsAtStart,
            rawBuildsAfterSwitch == rawBuildsAtStart + 1,
          ),
          (true, true, true, 0, true, true, true),
        );
      },
    );

    testWidgets(
      'when an arbitrary descendant transition can paint outside, it should preserve the positioned fallback',
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
                      tag: 'translated-raw-fallback',
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.linear,
                      nonMorphDescendantsTransition: (child, animation) {
                        return FractionalTranslation(
                          translation: const Offset(0.5, 0),
                          child: child,
                        );
                      },
                      child: Container(
                        key: ValueKey('translated-raw-$destination'),
                        width: destination ? 180 : 100,
                        height: destination ? 140 : 80,
                        color: destination ? Colors.blue : Colors.red,
                        child: const ColoredBox(color: Colors.green),
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
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          (
            find
                .byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_MorphHybridContainerFlight',
                )
                .evaluate()
                .length,
            find
                .byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_MorphPositionedFlight',
                )
                .evaluate()
                .length,
          ),
          (0, 1),
        );
      },
    );

    testWidgets(
      'when an ordinary descendant has no transition, it should retain its captured subtree between flight frames',
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
                      tag: 'retained-ordinary-raw',
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.linear,
                      child: Container(
                        key: ValueKey('retained-raw-$destination'),
                        width: 180,
                        height: 120,
                        color: destination ? Colors.blue : Colors.red,
                        child: ColoredBox(
                          key: ValueKey(
                            destination ? 'retained-arriving-raw-child' : 'retained-departing-raw-child',
                          ),
                          color: Colors.transparent,
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
        final hybridFlight = find.descendant(
          of: _morphOverlay(),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphHybridContainerFlight',
          ),
        );
        final hybridRenderObject = tester.renderObject<RenderBox>(
          hybridFlight,
        );
        int hybridLayoutCount() {
          return hybridRenderObject
                  .toDiagnosticsNode()
                  .getProperties()
                  .singleWhere(
                    (property) => property.name == 'layoutCount',
                  )
                  .value!
              as int;
        }

        final layoutCountAtStart = hybridLayoutCount();
        await tester.pump(const Duration(milliseconds: 40));
        await tester.pump(const Duration(milliseconds: 40));
        final layoutCountBeforeSwitch = hybridLayoutCount();
        final rawSlot = find.descendant(
          of: hybridFlight,
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphHybridRawSlot',
          ),
        );
        final retainedBoundaryCount = find
            .descendant(
              of: rawSlot,
              matching: find.byType(RepaintBoundary),
            )
            .evaluate()
            .length;
        final sourceSelectedBeforeSwitch = find
            .descendant(
              of: rawSlot,
              matching: find.byKey(
                const ValueKey('retained-departing-raw-child'),
              ),
            )
            .evaluate()
            .length;
        await tester.pump(const Duration(milliseconds: 160));
        final layoutCountAfterSwitch = hybridLayoutCount();
        final destinationSelectedAfterSwitch = find
            .descendant(
              of: rawSlot,
              matching: find.byKey(
                const ValueKey('retained-arriving-raw-child'),
              ),
            )
            .evaluate()
            .length;

        expect(
          (
            hybridFlight.evaluate().length,
            retainedBoundaryCount,
            sourceSelectedBeforeSwitch,
            destinationSelectedAfterSwitch,
            layoutCountBeforeSwitch == layoutCountAtStart,
            layoutCountAfterSwitch == layoutCountAtStart + 1,
          ),
          (1, 1, 1, 1, true, true),
        );
      },
    );

    testWidgets(
      'when raw ownership switches between different sizes, it should keep the interpolated child rect exact',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: [
                      Positioned(
                        left: destination ? 150 : 20,
                        top: destination ? 110 : 30,
                        child: Morph(
                          tag: 'exact-raw-rect',
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.linear,
                          child: Container(
                            key: ValueKey(
                              'exact-raw-rect-surface-$destination',
                            ),
                            width: destination ? 200 : 120,
                            height: destination ? 140 : 80,
                            padding: EdgeInsets.all(
                              destination ? 20 : 10,
                            ),
                            color: destination ? Colors.blue : Colors.red,
                            child: ColoredBox(
                              key: ValueKey(
                                'exact-raw-rect-child-$destination',
                              ),
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sourceBounds = tester.getRect(
          find.byKey(
            const ValueKey('exact-raw-rect-surface-false'),
          ),
        );

        update(() => destination = true);
        await tester.pump();
        final destinationBounds = tester.getRect(
          find.byKey(
            const ValueKey('exact-raw-rect-surface-true'),
          ),
        );
        await tester.pump();
        final rawSlot = find.descendant(
          of: _morphOverlay(),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphHybridRawSlot',
          ),
        );
        final retainedBoundaryCount = find
            .descendant(
              of: rawSlot,
              matching: find.byType(RepaintBoundary),
            )
            .evaluate()
            .length;
        bool rectsAreNear(Rect first, Rect second) {
          return (first.left - second.left).abs() < 0.001 &&
              (first.top - second.top).abs() < 0.001 &&
              (first.right - second.right).abs() < 0.001 &&
              (first.bottom - second.bottom).abs() < 0.001;
        }

        Rect expectedChildRect(double progress) {
          final root = Rect.lerp(
            sourceBounds,
            destinationBounds,
            progress,
          )!;
          final relative = Rect.lerp(
            const Rect.fromLTWH(10, 10, 100, 60),
            const Rect.fromLTWH(20, 20, 160, 100),
            progress,
          )!;
          return relative.shift(root.topLeft);
        }

        await tester.pump(const Duration(milliseconds: 196));
        final beforeSwitch = tester.getRect(rawSlot);
        final sourceSelected = find
            .descendant(
              of: rawSlot,
              matching: find.byKey(
                const ValueKey('exact-raw-rect-child-false'),
              ),
            )
            .evaluate()
            .length;
        await tester.pump(const Duration(milliseconds: 8));
        final afterSwitch = tester.getRect(rawSlot);
        final destinationSelected = find
            .descendant(
              of: rawSlot,
              matching: find.byKey(
                const ValueKey('exact-raw-rect-child-true'),
              ),
            )
            .evaluate()
            .length;

        expect(
          (
            rectsAreNear(beforeSwitch, expectedChildRect(0.49)),
            rectsAreNear(afterSwitch, expectedChildRect(0.51)),
            sourceSelected,
            destinationSelected,
            retainedBoundaryCount,
          ),
          (true, true, 1, 1, 0),
        );
      },
    );

    testWidgets(
      'when a raw descendant paints a shadow outside its bounds, it should use the overflow-safe fallback',
      (tester) async {
        tester.view.physicalSize = const Size(240, 180);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('raw-shadow-screen');
        const shadowColor = Color(0xFFFF00FF);
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Positioned(
                          left: 40,
                          top: 30,
                          child: Morph(
                            tag: 'raw-shadow-fallback',
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.linear,
                            child: Container(
                              key: ValueKey(
                                'raw-shadow-surface-$destination',
                              ),
                              width: 100,
                              height: 60,
                              color: Colors.transparent,
                              child: Builder(
                                key: ValueKey(
                                  'raw-shadow-child-$destination',
                                ),
                                builder: (context) {
                                  return const DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      boxShadow: [
                                        BoxShadow(
                                          color: shadowColor,
                                          offset: Offset(0, 20),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
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
        final frame = await _capturePixels(tester, boundaryKey);
        final offset = (100 * frame.width + 90) * 4;
        final pixel = Color.fromARGB(
          frame.pixels[offset + 3],
          frame.pixels[offset],
          frame.pixels[offset + 1],
          frame.pixels[offset + 2],
        );

        expect(
          (
            find
                .byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_MorphHybridContainerFlight',
                )
                .evaluate()
                .length,
            find
                .byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_MorphPositionedFlight',
                )
                .evaluate()
                .length,
            pixel.toARGB32(),
          ),
          (0, 1, shadowColor.toARGB32()),
        );
      },
    );

    testWidgets(
      'when a watched raw destination resizes, it should keep the geometry-aware positioned fallback',
      (tester) async {
        var destination = false;
        var destinationWidth = 180.0;
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
                      tag: 'watched-raw-fallback',
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.linear,
                      watch: destination,
                      child: Container(
                        key: ValueKey('watched-raw-$destination'),
                        width: destination ? destinationWidth : 100,
                        height: destination ? 140 : 80,
                        color: destination ? Colors.blue : Colors.red,
                        child: ColoredBox(
                          key: ValueKey(
                            'watched-raw-child-$destination',
                          ),
                          color: Colors.green,
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
        update(() => destinationWidth = 260);
        await tester.pump();
        await tester.pump();

        expect(
          (
            find
                .byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_MorphHybridContainerFlight',
                )
                .evaluate()
                .length,
            find
                .byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_MorphPositionedFlight',
                )
                .evaluate()
                .length,
            tester.takeException(),
          ),
          (0, 1, null),
        );
      },
    );

    testWidgets(
      'when only one endpoint has a raw child, it should preserve the positioned fallback',
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
                      tag: 'one-sided-raw-fallback',
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.linear,
                      child: Container(
                        key: ValueKey('one-sided-raw-$destination'),
                        width: destination ? 180 : 100,
                        height: destination ? 140 : 80,
                        color: destination ? Colors.blue : Colors.red,
                        child: destination
                            ? null
                            : const ColoredBox(
                                color: Colors.green,
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
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          (
            find
                .byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_MorphHybridContainerFlight',
                )
                .evaluate()
                .length,
            find
                .byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_MorphPositionedFlight',
                )
                .evaluate()
                .length,
            tester.takeException(),
          ),
          (0, 1, null),
        );
      },
    );

    testWidgets(
      'when a raw flight curve overshoots extreme sizes, it should keep normalized layout bounds',
      (tester) async {
        const boundaryKey = ValueKey('overshoot-raw-screen');
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                backgroundColor: Colors.white,
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Morph(
                        tag: 'overshoot-raw',
                        duration: const Duration(milliseconds: 400),
                        curve: const _ExtremeOvershootCurve(),
                        child: Container(
                          key: ValueKey('overshoot-raw-$destination'),
                          width: destination ? 200 : 100,
                          height: destination ? 160 : 80,
                          color: destination ? Colors.blue : Colors.red,
                          child: ColoredBox(
                            key: ValueKey(
                              'overshoot-raw-child-$destination',
                            ),
                            color: Colors.green,
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
        await tester.pump(const Duration(milliseconds: 200));
        final hybridFlight = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_MorphHybridContainerFlight',
        );
        final renderObject = tester.renderObject<RenderBox>(hybridFlight);
        Rect flightBounds() {
          return renderObject
                  .toDiagnosticsNode()
                  .getProperties()
                  .singleWhere(
                    (property) => property.name == 'flightBounds',
                  )
                  .value!
              as Rect;
        }

        final extrapolatedBounds = flightBounds();
        final rawSlot = find.descendant(
          of: hybridFlight,
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphHybridRawSlot',
          ),
        );
        final extrapolatedRawSize = tester.getSize(rawSlot);
        final extrapolatedFrame = await _capturePixels(tester, boundaryKey);
        final extrapolatedOffset = (20 * extrapolatedFrame.width + 95) * 4;
        final extrapolatedPixel = Color.fromARGB(
          extrapolatedFrame.pixels[extrapolatedOffset + 3],
          extrapolatedFrame.pixels[extrapolatedOffset],
          extrapolatedFrame.pixels[extrapolatedOffset + 1],
          extrapolatedFrame.pixels[extrapolatedOffset + 2],
        );

        await tester.pump(const Duration(milliseconds: 100));
        final collapsedBounds = flightBounds();
        final collapsedFrame = await _capturePixels(tester, boundaryKey);
        final collapsedOffset = (20 * collapsedFrame.width + 20) * 4;
        final collapsedPixel = Color.fromARGB(
          collapsedFrame.pixels[collapsedOffset + 3],
          collapsedFrame.pixels[collapsedOffset],
          collapsedFrame.pixels[collapsedOffset + 1],
          collapsedFrame.pixels[collapsedOffset + 2],
        );

        expect(
          (
            hybridFlight.evaluate().length,
            (extrapolatedBounds.width - 90).abs() < 0.001,
            (extrapolatedRawSize.width - 90).abs() < 0.001,
            extrapolatedPixel.toARGB32(),
            collapsedBounds.width,
            collapsedBounds.height,
            collapsedPixel.toARGB32(),
            tester.takeException(),
          ),
          (
            1,
            true,
            true,
            Colors.white.toARGB32(),
            0,
            0,
            Colors.white.toARGB32(),
            null,
          ),
        );
      },
    );

    testWidgets(
      'when a raw child has no MediaQuery, it should preserve the existing overlay behavior',
      (tester) async {
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) {
                    return StatefulBuilder(
                      builder: (context, setState) {
                        update = setState;
                        return Align(
                          alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                          child: Morph(
                            tag: 'no-media-query',
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.linear,
                            child: Container(
                              key: ValueKey('no-media-query-$destination'),
                              width: destination ? 180 : 120,
                              height: destination ? 120 : 80,
                              color: destination ? Colors.blue : Colors.red,
                              child: Builder(
                                builder: (context) {
                                  return const SizedBox(
                                    key: ValueKey(
                                      'no-media-query-raw-content',
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          (
            find
                .descendant(
                  of: _morphOverlay(),
                  matching: find.byKey(
                    const ValueKey('no-media-query-raw-content'),
                  ),
                )
                .evaluate()
                .length,
            tester.takeException(),
          ),
          (1, null),
        );
      },
    );

    testWidgets(
      'when a Container child contains a nested Morph, it should fly the surface and nested endpoint together',
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
                      tag: 'nested-surface',
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.linear,
                      nonMorphDescendantsTransition: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: Container(
                        key: ValueKey('nested-surface-$destination'),
                        width: destination ? 240 : 160,
                        height: destination ? 180 : 120,
                        color: destination ? Colors.blue : Colors.red,
                        child: Column(
                          children: [
                            Morph(
                              tag: 'nested-title',
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.linear,
                              child: Text(
                                destination ? 'Destination title' : 'Source title',
                                key: ValueKey('nested-title-$destination'),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(destination ? 'Destination content' : 'Source content'),
                              ),
                            ),
                          ],
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
        await tester.pump(const Duration(milliseconds: 100));
        final flightBoundaries = find.descendant(
          of: _morphOverlay(),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphFlightBoundary',
          ),
        );
        final error = tester.takeException();
        final sourceContentInFlight = find
            .descendant(
              of: _morphOverlay(),
              matching: find.text('Source content'),
            )
            .evaluate()
            .length;
        final destinationContentInFlight = find
            .descendant(
              of: _morphOverlay(),
              matching: find.text('Destination content'),
            )
            .evaluate()
            .length;

        expect(
          (
            flightBoundaries.evaluate().length,
            sourceContentInFlight,
            destinationContentInFlight,
            error,
          ),
          (2, 1, 0, null),
        );
      },
    );

    testWidgets(
      'when a nested flight completes before its parent, it should hold the destination visual until the parent arrives',
      (tester) async {
        var destination = false;
        final childEvents = <String>[];
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
                      tag: 'held-nested-surface',
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.linear,
                      child: Container(
                        key: ValueKey('held-nested-surface-$destination'),
                        width: destination ? 240 : 160,
                        height: destination ? 180 : 120,
                        color: destination ? Colors.blue : Colors.red,
                        child: Column(
                          children: [
                            Morph(
                              tag: 'held-nested-title',
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.linear,
                              onEnd: destination ? null : () => childEvents.add('end'),
                              onReceived: destination ? () => childEvents.add('received') : null,
                              child: Text(
                                destination ? 'Held destination title' : 'Held source title',
                                key: ValueKey(
                                  'held-nested-title-$destination',
                                ),
                              ),
                            ),
                            const Expanded(
                              child: SizedBox(),
                            ),
                          ],
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
        await tester.pump(const Duration(milliseconds: 250));
        final heldFlightError = tester.takeException();
        final heldFlightBoundaries = find
            .descendant(
              of: _morphOverlay(),
              matching: find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_MorphFlightBoundary',
              ),
            )
            .evaluate()
            .length;
        final heldHybridParentCount = find
            .descendant(
              of: _morphOverlay(),
              matching: find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_MorphHybridContainerFlight',
              ),
            )
            .evaluate()
            .length;
        final eventsWhileHeld = List<String>.of(childEvents);
        await tester.pumpAndSettle();
        final settledDestinationCount = find.text('Held destination title').evaluate().length;

        update(() => destination = false);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        final reverseHeldFlightBoundaries = find
            .descendant(
              of: _morphOverlay(),
              matching: find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_MorphFlightBoundary',
              ),
            )
            .evaluate()
            .length;
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        final teardownError = tester.takeException();

        expect(
          (
            heldFlightBoundaries,
            heldHybridParentCount,
            eventsWhileHeld.join(','),
            childEvents.join(','),
            settledDestinationCount,
            reverseHeldFlightBoundaries,
            heldFlightError,
            teardownError,
          ),
          (
            2,
            1,
            'received,end',
            'received,end',
            1,
            2,
            null,
            null,
          ),
        );
      },
    );

    testWidgets(
      'when supported compound children fly, it should paint without a per-frame widget builder',
      (tester) async {
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Align(
                  alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    tag: 'retained-compound',
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.linear,
                    child: Container(
                      width: destination ? 240 : 160,
                      height: destination ? 140 : 100,
                      padding: EdgeInsets.all(destination ? 24 : 12),
                      decoration: BoxDecoration(
                        color: destination ? Colors.blue : Colors.red,
                        borderRadius: BorderRadius.circular(
                          destination ? 32 : 12,
                        ),
                      ),
                      child: Text(
                        destination ? 'Destination title' : 'Source title',
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

        final animatedBuilders = find.descendant(
          of: _morphOverlay(),
          matching: find.byType(AnimatedBuilder),
        );
        final positionedTransitions = find.descendant(
          of: _morphOverlay(),
          matching: find.byType(PositionedTransition),
        );
        expect(
          (animatedBuilders.evaluate().length, positionedTransitions.evaluate().length),
          (1, 0),
        );
      },
    );

    testWidgets(
      'when a column is inside a container without a flight, it should render every child',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Morph(
                tag: 'compound-resting',
                child: Container(
                  width: 300,
                  height: 200,
                  color: Colors.white,
                  child: const Column(
                    children: [Text('Title'), Text('Description')],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          (find.text('Title').evaluate().length, find.text('Description').evaluate().length),
          (1, 1),
        );
      },
    );

    testWidgets(
      'when a Container child wraps with visible overflow, it should retain every native pixel below its bounds',
      (tester) async {
        tester.view.physicalSize = const Size(300, 180);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey<String>(
          'visible-container-boundary',
        );
        const text = 'Visible wrapped text stays red across every overflowing line.';
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Positioned(
                          left: 20,
                          top: 20,
                          child: Morph(
                            tag: 'visible-container',
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.linear,
                            child: Container(
                              key: ValueKey<String>(
                                'visible-container-$destination',
                              ),
                              width: 110,
                              height: 28,
                              color: Colors.transparent,
                              child: const Text(
                                text,
                                overflow: TextOverflow.visible,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final resting = await _capturePixels(tester, boundaryKey);

        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final flight = await _capturePixels(tester, boundaryKey);
        const overflowRegion = Rect.fromLTRB(15, 48, 140, 160);
        const textRegion = Rect.fromLTRB(15, 15, 140, 165);
        final observed = (
          find
              .byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_MorphCompoundFlight',
              )
              .evaluate()
              .length,
          find.byType(PositionedTransition).evaluate().length,
          _redPixelCount(resting, overflowRegion) > 0,
          _pixelsMatch(resting, flight, textRegion),
        );
        await tester.pumpAndSettle();

        expect(observed, (1, 0, true, true));
      },
    );

    testWidgets(
      'when a compound container shrinks, it should clamp its long text during flight',
      (tester) async {
        await tester.pumpWidget(const _ContainerClampTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle-clamp')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));

        final text = _flightText(tester, _ContainerClampTestApp.longText);
        expect(text.maxLines, isNotNull);
      },
    );

    testWidgets(
      'when a compound container shrinks, it should retain every matched child during flight',
      (tester) async {
        await tester.pumpWidget(const _ContainerClampTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle-clamp')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));

        expect(
          (
            _flightTextCount(tester, 'Title'),
            _flightTextCount(tester, 'Subtitle'),
            _flightTextCount(tester, _ContainerClampTestApp.longText),
          ),
          (1, 1, 1),
        );
      },
    );

    testWidgets(
      'when a compound container flies twice, it should clamp on the second flight too',
      (tester) async {
        await tester.pumpWidget(const _ContainerClampTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('toggle-clamp')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('toggle-clamp')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('toggle-clamp')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));

        expect(
          _flightText(tester, _ContainerClampTestApp.longText).maxLines,
          isNotNull,
        );
      },
    );

    testWidgets(
      'when a directional Container flies from a local RTL subtree, it should preserve RTL alignment and border radius',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        const screenKey = ValueKey('rtl-container-screen');
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: screenKey,
            child: MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return Align(
                        alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                        child: Morph(
                          tag: 'local-rtl-container',
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.linear,
                          child: Container(
                            key: ValueKey(
                              destination ? 'rtl-container-destination' : 'rtl-container-source',
                            ),
                            width: 160,
                            height: 100,
                            alignment: AlignmentDirectional.centerStart,
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadiusDirectional.only(
                                topStart: Radius.circular(36),
                              ),
                            ),
                            child: const ColoredBox(
                              color: Colors.green,
                              child: SizedBox.square(dimension: 20),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sourceBounds = tester.getRect(
          find.byKey(const ValueKey('rtl-container-source')),
        );

        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final destinationBounds = tester.getRect(
          find.byKey(const ValueKey('rtl-container-destination')),
        );
        final flightBounds = Rect.lerp(
          sourceBounds,
          destinationBounds,
          0.5,
        )!;
        final screenBounds = tester.getRect(find.byKey(screenKey));
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(screenKey),
        );
        final sampled = (await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            Color pixel(double x, double y) {
              final localX = (x - screenBounds.left).round();
              final localY = (y - screenBounds.top).round();
              final offset = (localY * image.width + localX) * 4;
              return Color.fromARGB(
                bytes!.getUint8(offset + 3),
                bytes.getUint8(offset),
                bytes.getUint8(offset + 1),
                bytes.getUint8(offset + 2),
              );
            }

            return (
              rightCenter: pixel(
                flightBounds.right - 5,
                flightBounds.center.dy,
              ),
              leftCenter: pixel(
                flightBounds.left + 5,
                flightBounds.center.dy,
              ),
              topRight: pixel(
                flightBounds.right - 2,
                flightBounds.top + 2,
              ),
              topLeft: pixel(
                flightBounds.left + 2,
                flightBounds.top + 2,
              ),
            );
          } finally {
            image.dispose();
          }
        }))!;
        bool isGreen(Color color) => color.g > 0.6 && color.r < 0.4;
        bool isRed(Color color) => color.r > 0.7 && color.g < 0.3;
        bool isWhite(Color color) => color.r > 0.9 && color.g > 0.9 && color.b > 0.9;

        expect(
          (
            isGreen(sampled.rightCenter),
            isRed(sampled.leftCenter),
            isWhite(sampled.topRight),
            isRed(sampled.topLeft),
          ),
          (true, true, true, true),
        );
      },
    );

    testWidgets(
      'when a directional gradient flies from a local RTL subtree, it should preserve its resolved direction',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        const screenKey = ValueKey('rtl-gradient-screen');
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: screenKey,
            child: MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return Center(
                        child: Morph(
                          tag: 'rtl-gradient',
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.linear,
                          child: Container(
                            key: ValueKey('rtl-gradient-$destination'),
                            width: 160,
                            height: 80,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: AlignmentDirectional.centerStart,
                                end: AlignmentDirectional.centerEnd,
                                colors: [Colors.red, Colors.blue],
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
          ),
        );
        await tester.pumpAndSettle();
        final bounds = tester.getRect(
          find.byKey(const ValueKey('rtl-gradient-false')),
        );
        final screenBounds = tester.getRect(find.byKey(screenKey));

        Future<(Color, Color)> sampleEdges() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(screenKey),
          );
          return (await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              Color pixel(double globalX) {
                final x = (globalX - screenBounds.left).round();
                final y = (bounds.center.dy - screenBounds.top).round();
                final offset = (y * image.width + x) * 4;
                return Color.fromARGB(
                  bytes!.getUint8(offset + 3),
                  bytes.getUint8(offset),
                  bytes.getUint8(offset + 1),
                  bytes.getUint8(offset + 2),
                );
              }

              return (
                pixel(bounds.left + 10),
                pixel(bounds.right - 10),
              );
            } finally {
              image.dispose();
            }
          }))!;
        }

        final restingEdges = await sampleEdges();
        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        final flightEdges = await sampleEdges();
        await tester.pumpAndSettle();
        bool isBlue(Color color) => color.b > color.r;
        bool isRed(Color color) => color.r > color.b;

        expect(
          (
            isBlue(restingEdges.$1),
            isRed(restingEdges.$2),
            isBlue(flightEdges.$1),
            isRed(flightEdges.$2),
          ),
          (true, true, true, true),
        );
      },
    );

    testWidgets(
      'when a directional border flies from a local RTL subtree, it should preserve its resolved sides',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        const screenKey = ValueKey('rtl-border-screen');
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: screenKey,
            child: MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return Center(
                        child: Morph(
                          tag: 'rtl-border',
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.linear,
                          child: Container(
                            key: ValueKey('rtl-border-$destination'),
                            width: 160,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: BorderDirectional(
                                start: BorderSide(
                                  color: Colors.red,
                                  width: 12,
                                ),
                                end: BorderSide(
                                  color: Colors.blue,
                                  width: 12,
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
          ),
        );
        await tester.pumpAndSettle();
        final bounds = tester.getRect(
          find.byKey(const ValueKey('rtl-border-false')),
        );
        final screenBounds = tester.getRect(find.byKey(screenKey));

        Future<(Color, Color)> sampleEdges() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(screenKey),
          );
          return (await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              Color pixel(double globalX) {
                final x = (globalX - screenBounds.left).round();
                final y = (bounds.center.dy - screenBounds.top).round();
                final offset = (y * image.width + x) * 4;
                return Color.fromARGB(
                  bytes!.getUint8(offset + 3),
                  bytes.getUint8(offset),
                  bytes.getUint8(offset + 1),
                  bytes.getUint8(offset + 2),
                );
              }

              return (
                pixel(bounds.left + 3),
                pixel(bounds.right - 3),
              );
            } finally {
              image.dispose();
            }
          }))!;
        }

        final restingEdges = await sampleEdges();
        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        final flightEdges = await sampleEdges();
        await tester.pumpAndSettle();
        bool isBlue(Color color) => color.b > color.r;
        bool isRed(Color color) => color.r > color.b;

        expect(
          (
            isBlue(restingEdges.$1),
            isRed(restingEdges.$2),
            isBlue(flightEdges.$1),
            isRed(flightEdges.$2),
          ),
          (true, true, true, true),
        );
      },
    );

    testWidgets(
      'when a rounded Container flies under a uniform scale, it should preserve the scaled corner radius',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        const screenKey = ValueKey('scaled-container-screen');
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: screenKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Center(
                      child: Transform.scale(
                        scale: 2,
                        child: Morph(
                          tag: 'scaled-rounded-container',
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.linear,
                          child: Container(
                            key: ValueKey('scaled-container-$destination'),
                            width: 100,
                            height: 100,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.all(
                                Radius.circular(30),
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
        final bounds = tester.getRect(
          find.byKey(const ValueKey('scaled-container-false')),
        );
        final screenBounds = tester.getRect(find.byKey(screenKey));

        Future<Color> sampleCorner() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(screenKey),
          );
          return (await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              final x = (bounds.left + 10 - screenBounds.left).round();
              final y = (bounds.top + 20 - screenBounds.top).round();
              final offset = (y * image.width + x) * 4;
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

        final restingCorner = await sampleCorner();
        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        final flightCorner = await sampleCorner();
        bool isWhite(Color color) => color.r > 0.9 && color.g > 0.9 && color.b > 0.9;

        expect(
          (isWhite(restingCorner), isWhite(flightCorner)),
          (true, true),
        );
      },
    );

    testWidgets(
      'when a shadowed Container flies under a non-uniform scale, it should preserve the transformed shadow offset',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        const screenKey = ValueKey('scaled-shadow-screen');
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: screenKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Center(
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(2, 1, 1),
                        child: Morph(
                          tag: 'scaled-shadow',
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.linear,
                          child: Container(
                            key: ValueKey('scaled-shadow-$destination'),
                            width: 100,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green,
                                  offset: Offset(20, 0),
                                ),
                              ],
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
        final bounds = tester.getRect(
          find.byKey(const ValueKey('scaled-shadow-false')),
        );
        final screenBounds = tester.getRect(find.byKey(screenKey));

        Future<Color> sampleShadow() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(screenKey),
          );
          return (await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              final x = (bounds.right + 35 - screenBounds.left).round();
              final y = (bounds.center.dy - screenBounds.top).round();
              final offset = (y * image.width + x) * 4;
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

        final restingShadow = await sampleShadow();
        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        final flightShadow = await sampleShadow();
        await tester.pumpAndSettle();
        bool isGreen(Color color) => color.g > color.r + 0.1 && color.g > color.b + 0.1;

        expect(
          (isGreen(restingShadow), isGreen(flightShadow)),
          (true, true),
        );
      },
    );

    testWidgets(
      'when an outer transform rotates a Container, it should use the generic flight without an error',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        const screenKey = ValueKey('rotated-container-screen');
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: screenKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Center(
                      child: Transform.rotate(
                        angle: math.pi / 4,
                        child: Morph(
                          tag: 'rotated-container',
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.linear,
                          child: Container(
                            key: ValueKey('rotated-container-$destination'),
                            width: 100,
                            height: 40,
                            color: Colors.red,
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
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(screenKey),
        );
        final container = tester.renderObject<RenderBox>(
          find.byKey(const ValueKey('rotated-container-false')),
        );
        final bounds = MatrixUtils.transformRect(
          container.getTransformTo(boundary),
          Offset.zero & container.size,
        );

        Future<Color> sampleCorner() async {
          return (await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              final x = (bounds.left + 5).round();
              final y = (bounds.top + 5).round();
              final offset = (y * image.width + x) * 4;
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

        final restingCorner = await sampleCorner();
        update(() => destination = true);
        await tester.pump();
        final diagnostic = tester.takeException();
        await tester.pump();
        final destinationCorner = await sampleCorner();
        final overlayCount = _morphOverlay().evaluate().length;
        bool isWhite(Color color) => color.r > 0.9 && color.g > 0.9 && color.b > 0.9;

        expect(
          (
            isWhite(restingCorner),
            isWhite(destinationCorner),
            overlayCount,
            diagnostic is ArgumentError,
          ),
          (true, false, 1, false),
        );
      },
    );

    testWidgets(
      'when Container transform rotates its own content, it should use the generic flight without an error',
      (tester) async {
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Center(
                    child: Morph(
                      tag: 'self-rotated-container',
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.linear,
                      child: Container(
                        key: ValueKey('self-rotated-container-$destination'),
                        width: 100,
                        height: 40,
                        color: Colors.red,
                        transform: Matrix4.rotationZ(math.pi / 4),
                        transformAlignment: Alignment.center,
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
        final diagnostic = tester.takeException();
        await tester.pump();

        expect(
          (
            _morphOverlay().evaluate().length,
            diagnostic is ArgumentError,
          ),
          (1, false),
        );
      },
    );
  });
}

class _ContainerClampTestApp extends StatefulWidget {
  const _ContainerClampTestApp();

  static const longText =
      'This long description has enough content to span several lines while '
      'the surrounding container returns to its compact height.';

  @override
  State<_ContainerClampTestApp> createState() => _ContainerClampTestAppState();
}

class _ContainerClampTestAppState extends State<_ContainerClampTestApp> {
  bool _compact = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            FilledButton(
              key: const ValueKey('toggle-clamp'),
              onPressed: () => setState(() => _compact = !_compact),
              child: const Text('Toggle'),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Morph(
                tag: 'container-clamp',
                duration: const Duration(milliseconds: 400),
                curve: Curves.linear,
                child: Container(
                  key: ValueKey(_compact ? 'compact' : 'expanded'),
                  width: 300,
                  height: _compact ? 120 : 240,
                  padding: const EdgeInsets.all(8),
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(color: Colors.white),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Title'),
                      const Text('Subtitle'),
                      Text(
                        _ContainerClampTestApp.longText,
                        maxLines: _compact ? 2 : null,
                        overflow: _compact ? TextOverflow.ellipsis : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
