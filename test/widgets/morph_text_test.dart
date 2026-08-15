import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/morph/morph.dart'
    show MorphColumnFlightDelegate, MorphColumnProperties, MorphTextFlightDelegate, MorphTextProperties;

class _MorphColumnPropertiesHarness extends StatelessWidget {
  const _MorphColumnPropertiesHarness({required this.properties});

  final MorphColumnProperties properties;

  @override
  Widget build(BuildContext context) {
    final endpoint = MorphEndpoint<MorphColumnProperties>(
      properties: properties,
      bounds: const Rect.fromLTWH(0, 0, 270, 60),
      localSize: const Size(270, 60),
      transform: Matrix4.identity(),
      axisScale: const Offset(1, 1),
    );
    return const MorphColumnFlightDelegate().buildFlight(
      context,
      MorphFlight<MorphColumnProperties>(
        source: endpoint,
        destination: endpoint,
        kind: MorphFlightKind.sameScreen,
        animation: const AlwaysStoppedAnimation<double>(0),
        flightDelegate: const MorphColumnFlightDelegate(),
      ),
    );
  }
}

class _MorphTextFlightHarness extends StatelessWidget {
  const _MorphTextFlightHarness({required this.properties});

  final MorphTextProperties properties;

  @override
  Widget build(BuildContext context) {
    final endpoint = MorphEndpoint<MorphTextProperties>(
      properties: properties,
      bounds: const Rect.fromLTWH(0, 0, 200, 60),
      localSize: const Size(200, 60),
      transform: Matrix4.identity(),
      axisScale: const Offset(1, 1),
    );
    const delegate = MorphTextFlightDelegate();
    return delegate.buildFlight(
      context,
      MorphFlight<MorphTextProperties>(
        source: endpoint,
        destination: endpoint,
        kind: MorphFlightKind.sameScreen,
        animation: const AlwaysStoppedAnimation<double>(0),
        flightDelegate: delegate,
      ),
    );
  }
}

class _AnimatedMorphTextFlightHarness extends StatelessWidget {
  const _AnimatedMorphTextFlightHarness({
    required this.source,
    required this.destination,
    required this.animation,
  });

  final MorphTextProperties source;
  final MorphTextProperties destination;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    const delegate = MorphTextFlightDelegate();
    return delegate.buildFlight(
      context,
      MorphFlight<MorphTextProperties>(
        source: MorphEndpoint<MorphTextProperties>(
          properties: source,
          bounds: const Rect.fromLTWH(0, 0, 300, 80),
          localSize: const Size(300, 80),
          transform: Matrix4.identity(),
          axisScale: const Offset(1, 1),
        ),
        destination: MorphEndpoint<MorphTextProperties>(
          properties: destination,
          bounds: const Rect.fromLTWH(0, 0, 300, 80),
          localSize: const Size(300, 80),
          transform: Matrix4.identity(),
          axisScale: const Offset(1, 1),
        ),
        kind: MorphFlightKind.sameScreen,
        animation: animation,
        flightDelegate: delegate,
      ),
    );
  }
}

RenderBox _retainedTextRenderObject(WidgetTester tester) {
  return tester.renderObject<RenderBox>(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_MorphTextFlight',
    ),
  );
}

T? _retainedTextDiagnostic<T>(WidgetTester tester, String name) {
  return _retainedTextRenderObject(
        tester,
      ).toDiagnosticsNode().getProperties().singleWhere((property) => property.name == name).value
      as T?;
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

MorphTextProperties _textProperties(
  WidgetTester tester,
  Key key, {
  required double switchThreshold,
}) {
  final finder = find.byKey(key);
  final renderBox = tester.renderObject<RenderBox>(finder);
  return MorphTextFlightDelegate.captureText(
    context: tester.element(finder),
    text: tester.widget<Text>(finder),
    size: renderBox.size,
    axisScale: const Offset(1, 1),
    switchThreshold: switchThreshold,
  );
}

void main() {
  group('Morph Text', () {
    test('when no curve is provided, it should defer curve resolution', () {
      const morph = Morph(tag: 'default-curve', child: Text('Text'));

      expect(morph.curve, isNull);
    });

    testWidgets(
      'when building at rest, it should display the original text without a repaint boundary',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Morph(
                tag: 'resting-text',
                child: Text(
                  'Resting text',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        );

        expect(
          (
            find.text('Resting text').evaluate().length,
            find
                .descendant(
                  of: find.byWidgetPredicate((widget) => widget is Morph),
                  matching: find.byType(RepaintBoundary),
                )
                .evaluate()
                .length,
          ),
          (1, 0),
        );
      },
    );

    testWidgets(
      'when Text flies under a non-uniform scale, it should preserve the transformed vertical extent',
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
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(2, 1, 1),
                      child: Morph(
                        tag: 'non-uniform-text',
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.linear,
                        child: Text(
                          'Non-uniform scale',
                          key: ValueKey('non-uniform-text-$destination'),
                          style: const TextStyle(fontSize: 20),
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
        final restingHeight = tester
            .getRect(
              find.byKey(const ValueKey('non-uniform-text-false')),
            )
            .height;

        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        final flightHeight = _retainedTextDiagnostic<double>(
          tester,
          'paintedTextHeight',
        )!;
        await tester.pumpAndSettle();

        expect(flightHeight, closeTo(restingHeight, 0.01));
      },
    );

    testWidgets(
      'when scaled Text uses a forced strut, it should preserve the transformed strut height',
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
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(1, 2, 1),
                      child: Morph(
                        tag: 'scaled-strut',
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.linear,
                        child: Text(
                          'Forced strut',
                          key: ValueKey('scaled-strut-$destination'),
                          style: const TextStyle(fontSize: 10),
                          strutStyle: const StrutStyle(
                            forceStrutHeight: true,
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
        final restingHeight = tester
            .getRect(
              find.byKey(const ValueKey('scaled-strut-false')),
            )
            .height;

        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        final flightHeight = _retainedTextDiagnostic<double>(
          tester,
          'paintedTextHeight',
        )!;
        await tester.pumpAndSettle();

        expect(flightHeight, closeTo(restingHeight, 0.01));
      },
    );

    testWidgets(
      'when forced-strut endpoints use different vertical scales, it should preserve exact interpolated metrics',
      (tester) async {
        const textKey = ValueKey<String>('forced-strut-metrics');
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text(
                'Forced metrics',
                key: textKey,
                style: TextStyle(fontSize: 10),
                strutStyle: StrutStyle(
                  fontSize: 30,
                  forceStrutHeight: true,
                ),
              ),
            ),
          ),
        );
        final element = tester.element(find.byKey(textKey));
        final text = tester.widget<Text>(find.byKey(textKey));
        final source = MorphTextFlightDelegate.captureText(
          context: element,
          text: text,
          size: const Size(200, 60),
          axisScale: const Offset(2, 2),
          switchThreshold: 0.5,
        );
        final destination = MorphTextFlightDelegate.captureText(
          context: element,
          text: text,
          size: const Size(100, 30),
          axisScale: const Offset(1, 1),
          switchThreshold: 0.5,
        );
        const delegate = MorphTextFlightDelegate();
        final quarter = delegate.lerp(source, destination, 0.25);
        final threeQuarters = delegate.lerp(
          source,
          destination,
          0.75,
        );

        ({double baseline, double height, double lineHeight}) visualMetrics(
          MorphTextProperties properties,
        ) {
          final painter = TextPainter(
            text: TextSpan(
              text: properties.text,
              style: properties.paintStyle,
            ),
            textAlign: properties.textAlign ?? TextAlign.start,
            textDirection: properties.textDirection,
            textScaler: properties.textScaler,
            locale: properties.locale,
            textWidthBasis: properties.textWidthBasis ?? TextWidthBasis.parent,
            textHeightBehavior: properties.textHeightBehavior,
            strutStyle: properties.strutStyle,
            maxLines: properties.maxLines,
            ellipsis: properties.overflow == TextOverflow.ellipsis ? '…' : null,
          );
          try {
            painter.layout(maxWidth: properties.reservedLayoutWidth!);
            final firstLine = painter.computeLineMetrics().first;
            final baseline = firstLine.baseline * properties.paintScaleY + properties.baselineOffset;
            return (
              baseline: baseline,
              height: painter.height * properties.paintScaleY,
              lineHeight: firstLine.height * properties.paintScaleY,
            );
          } finally {
            painter.dispose();
          }
        }

        final quarterMetrics = visualMetrics(quarter);
        final threeQuarterMetrics = visualMetrics(threeQuarters);
        double lerp(double source, double destination, double progress) {
          return source + (destination - source) * progress;
        }

        bool isClose(double actual, double expected) {
          return (actual - expected).abs() < 0.000001;
        }

        expect(
          (
            source.strutStyle!.fontSize == 60,
            destination.strutStyle!.fontSize == 30,
            isClose(
              quarterMetrics.lineHeight,
              lerp(source.lineHeight, destination.lineHeight, 0.25),
            ),
            isClose(
              quarterMetrics.baseline,
              lerp(source.baseline, destination.baseline, 0.25),
            ),
            isClose(quarter.estimatedHeight, quarterMetrics.height),
            isClose(
              threeQuarterMetrics.lineHeight,
              lerp(source.lineHeight, destination.lineHeight, 0.75),
            ),
            isClose(
              threeQuarterMetrics.baseline,
              lerp(source.baseline, destination.baseline, 0.75),
            ),
            isClose(
              threeQuarters.estimatedHeight,
              threeQuarterMetrics.height,
            ),
          ),
          (true, true, true, true, true, true, true, true),
        );
      },
    );

    testWidgets(
      'when Text has an overflowing shadow, it should preserve the native shadow outside its layout bounds during flight',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        const screenKey = ValueKey('shadow-overflow-screen');
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
                      child: Morph(
                        tag: 'shadow-overflow',
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.linear,
                        child: Text(
                          'Shadow',
                          key: ValueKey('shadow-overflow-$destination'),
                          style: const TextStyle(
                            color: Color(0x00000000),
                            fontSize: 40,
                            shadows: [
                              Shadow(
                                color: Colors.red,
                                offset: Offset(80, 0),
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
          ),
        );
        await tester.pumpAndSettle();
        final bounds = tester.getRect(
          find.byKey(const ValueKey('shadow-overflow-false')),
        );
        final screenBounds = tester.getRect(find.byKey(screenKey));

        Future<int> overflowingRedPixels() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(screenKey),
          );
          return (await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              final left = (bounds.right - screenBounds.left).ceil().clamp(
                0,
                image.width,
              );
              final right = (bounds.right + 120 - screenBounds.left).ceil().clamp(
                0,
                image.width,
              );
              final top = (bounds.top - 10 - screenBounds.top).floor().clamp(
                0,
                image.height,
              );
              final bottom = (bounds.bottom + 10 - screenBounds.top).ceil().clamp(
                0,
                image.height,
              );
              var count = 0;
              for (var y = top; y < bottom; y += 1) {
                for (var x = left; x < right; x += 1) {
                  final offset = (y * image.width + x) * 4;
                  final red = bytes!.getUint8(offset);
                  final green = bytes.getUint8(offset + 1);
                  final blue = bytes.getUint8(offset + 2);
                  if (red > 180 && green < 100 && blue < 100) count += 1;
                }
              }
              return count;
            } finally {
              image.dispose();
            }
          }))!;
        }

        final restingOverflow = await overflowingRedPixels();
        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        final flightOverflow = await overflowingRedPixels();

        expect(
          (restingOverflow > 0, flightOverflow > 0),
          (true, true),
        );
      },
    );

    testWidgets(
      'when inside a bounded width, it should reserve the full width',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: Morph(tag: 'bounded-text', child: Text('Bounded')),
              ),
            ),
          ),
        );

        final morph = find.byWidgetPredicate((widget) => widget is Morph);
        expect(tester.getSize(morph).width, 300);
      },
    );

    testWidgets(
      'when building with a custom style, it should preserve that style at rest',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Morph(
                tag: 'styled-text',
                child: Text(
                  'Styled text',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        );

        expect(
          tester.widget<Text>(find.text('Styled text')).style,
          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        );
      },
    );

    testWidgets(
      'when plain text changes style and content, it should render the destination after the flight',
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
                    tag: 'text',
                    switchThreshold: 0.6,
                    child: (destination
                        ? const Text(
                            'Full description',
                            style: TextStyle(fontSize: 30),
                          )
                        : const Text(
                            'Summary',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        update(() => destination = true);
        await tester.pumpAndSettle();

        expect(find.text('Full description'), findsOneWidget);
      },
    );

    testWidgets(
      'when text differs, it should switch content at the departing threshold',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Text('Source', key: ValueKey('source')),
                  Text('Destination', key: ValueKey('destination')),
                ],
              ),
            ),
          ),
        );
        final source = _textProperties(
          tester,
          const ValueKey('source'),
          switchThreshold: 0.8,
        );
        final destination = _textProperties(
          tester,
          const ValueKey('destination'),
          switchThreshold: 0.2,
        );
        const delegate = MorphTextFlightDelegate(switchThreshold: 0.8);

        expect(
          (
            delegate.lerp(source, destination, 0.79).text,
            delegate.lerp(source, destination, 0.8).text,
          ),
          ('Source', 'Destination'),
        );
      },
    );

    testWidgets(
      'when interpolation progress is zero, it should retain the exact source properties',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Text(
                    'Source',
                    key: ValueKey('zero-source'),
                    style: TextStyle(fontSize: 22),
                  ),
                  Text(
                    'Destination',
                    key: ValueKey('zero-destination'),
                    style: TextStyle(fontSize: 34),
                  ),
                ],
              ),
            ),
          ),
        );
        final source = _textProperties(
          tester,
          const ValueKey('zero-source'),
          switchThreshold: 0,
        );
        final destination = _textProperties(
          tester,
          const ValueKey('zero-destination'),
          switchThreshold: 0,
        );

        expect(
          identical(
            const MorphTextFlightDelegate().lerp(source, destination, 0),
            source,
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'when interpolation progress is complete, it should retain the exact destination properties',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Text(
                    'Source',
                    key: ValueKey('complete-source'),
                    style: TextStyle(fontSize: 22),
                  ),
                  Text(
                    'Destination',
                    key: ValueKey('complete-destination'),
                    style: TextStyle(fontSize: 34),
                  ),
                ],
              ),
            ),
          ),
        );
        final source = _textProperties(
          tester,
          const ValueKey('complete-source'),
          switchThreshold: 0,
        );
        final destination = _textProperties(
          tester,
          const ValueKey('complete-destination'),
          switchThreshold: 0,
        );

        expect(
          identical(
            const MorphTextFlightDelegate().lerp(source, destination, 1),
            destination,
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'when font style changes, it should interpolate the style continuously',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Text(
                    'Text',
                    key: ValueKey('small'),
                    style: TextStyle(fontSize: 10),
                  ),
                  Text(
                    'Text',
                    key: ValueKey('large'),
                    style: TextStyle(fontSize: 30),
                  ),
                ],
              ),
            ),
          ),
        );
        final source = _textProperties(
          tester,
          const ValueKey('small'),
          switchThreshold: 0.5,
        );
        final destination = _textProperties(
          tester,
          const ValueKey('large'),
          switchThreshold: 0.5,
        );

        expect(
          const MorphTextFlightDelegate().lerp(source, destination, 0.5).style.fontSize,
          20,
        );
      },
    );

    testWidgets(
      'when font size changes during a flight, it should paint with the destination font and scale the glyphs continuously',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Text(
                    'Text',
                    key: ValueKey('stable-small'),
                    style: TextStyle(fontSize: 22),
                  ),
                  Text(
                    'Text',
                    key: ValueKey('stable-large'),
                    style: TextStyle(fontSize: 34),
                  ),
                ],
              ),
            ),
          ),
        );
        final source = _textProperties(
          tester,
          const ValueKey('stable-small'),
          switchThreshold: 0.5,
        );
        final destination = _textProperties(
          tester,
          const ValueKey('stable-large'),
          switchThreshold: 0.5,
        );
        const delegate = MorphTextFlightDelegate();
        final quarter = delegate.lerp(source, destination, 0.25);
        final midpoint = delegate.lerp(source, destination, 0.5);
        final threeQuarters = delegate.lerp(source, destination, 0.75);

        expect(
          [
            quarter.paintStyle.fontSize,
            quarter.paintScaleX,
            midpoint.paintStyle.fontSize,
            midpoint.paintScaleX,
            threeQuarters.paintStyle.fontSize,
            threeQuarters.paintScaleX,
          ],
          [
            34,
            closeTo(25 / 34, 0.000001),
            34,
            closeTo(28 / 34, 0.000001),
            34,
            closeTo(31 / 34, 0.000001),
          ],
        );
      },
    );

    testWidgets(
      'when endpoint line metrics differ, it should preserve the interpolated line height and baseline after scaling',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Text(
                    'Text',
                    key: ValueKey('short-line'),
                    style: TextStyle(fontSize: 22, height: 1.1),
                  ),
                  Text(
                    'Text',
                    key: ValueKey('tall-line'),
                    style: TextStyle(fontSize: 34, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        );
        final source = _textProperties(
          tester,
          const ValueKey('short-line'),
          switchThreshold: 0.5,
        );
        final destination = _textProperties(
          tester,
          const ValueKey('tall-line'),
          switchThreshold: 0.5,
        );
        final midpoint = const MorphTextFlightDelegate().lerp(
          source,
          destination,
          0.5,
        );
        final expectedLineHeight = source.lineHeight + (destination.lineHeight - source.lineHeight) * 0.5;
        final expectedBaseline = source.baseline + (destination.baseline - source.baseline) * 0.5;

        expect(
          [
            midpoint.paintScaleY * destination.lineHeight,
            midpoint.baselineOffset + midpoint.paintScaleY * destination.baseline,
          ],
          [
            closeTo(expectedLineHeight, 0.000001),
            closeTo(expectedBaseline, 0.000001),
          ],
        );
      },
    );

    testWidgets(
      'when text is captured at rest, it should retain its own paint style without scaling',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text(
                'Resting metrics',
                key: ValueKey('resting-metrics'),
                style: TextStyle(fontSize: 22),
              ),
            ),
          ),
        );
        final properties = _textProperties(
          tester,
          const ValueKey('resting-metrics'),
          switchThreshold: 0.5,
        );

        expect(
          [
            properties.paintStyle,
            properties.paintScaleX,
            properties.paintScaleY,
            properties.baselineOffset,
            properties.reservedLayoutWidth,
          ],
          [properties.style, 1.0, 1.0, 0.0, isNull],
        );
      },
    );

    testWidgets(
      'when text properties are captured, it should dispose the measurement painter',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text('Measured', key: ValueKey('measured-text')),
            ),
          ),
        );
        final created = <TextPainter>{};
        final disposed = <TextPainter>{};
        void listener(ObjectEvent event) {
          final object = event.object;
          if (object is! TextPainter) return;
          if (event is ObjectCreated) created.add(object);
          if (event is ObjectDisposed) disposed.add(object);
        }

        FlutterMemoryAllocations.instance.addListener(listener);
        addTearDown(
          () => FlutterMemoryAllocations.instance.removeListener(listener),
        );
        _textProperties(
          tester,
          const ValueKey('measured-text'),
          switchThreshold: 0.5,
        );
        FlutterMemoryAllocations.instance.removeListener(listener);

        expect((created.length, disposed.containsAll(created)), (1, true));
      },
    );

    testWidgets(
      'when text properties interpolate, it should dispose the height measurement painter',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Text(
                    'Short',
                    key: ValueKey('measurement-source'),
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    'A longer destination',
                    key: ValueKey('measurement-destination'),
                    style: TextStyle(fontSize: 30),
                  ),
                ],
              ),
            ),
          ),
        );
        final source = _textProperties(
          tester,
          const ValueKey('measurement-source'),
          switchThreshold: 0.5,
        );
        final destination = _textProperties(
          tester,
          const ValueKey('measurement-destination'),
          switchThreshold: 0.5,
        );
        final created = <TextPainter>{};
        final disposed = <TextPainter>{};
        void listener(ObjectEvent event) {
          final object = event.object;
          if (object is! TextPainter) return;
          if (event is ObjectCreated) created.add(object);
          if (event is ObjectDisposed) disposed.add(object);
        }

        FlutterMemoryAllocations.instance.addListener(listener);
        addTearDown(
          () => FlutterMemoryAllocations.instance.removeListener(listener),
        );
        const MorphTextFlightDelegate().lerp(source, destination, 0.5);
        FlutterMemoryAllocations.instance.removeListener(listener);

        expect((created.length, disposed.containsAll(created)), (1, true));
      },
    );

    testWidgets(
      'when a text flight unmounts, it should dispose its retained painter',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text('Flight', key: ValueKey('flight-properties')),
            ),
          ),
        );
        final properties = _textProperties(
          tester,
          const ValueKey('flight-properties'),
          switchThreshold: 0.5,
        );
        final created = <TextPainter>{};
        final disposed = <TextPainter>{};
        void listener(ObjectEvent event) {
          final object = event.object;
          if (object is! TextPainter) return;
          if (event is ObjectCreated) created.add(object);
          if (event is ObjectDisposed) disposed.add(object);
        }

        FlutterMemoryAllocations.instance.addListener(listener);
        addTearDown(
          () => FlutterMemoryAllocations.instance.removeListener(listener),
        );
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 200,
              height: 60,
              child: _MorphTextFlightHarness(properties: properties),
            ),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        FlutterMemoryAllocations.instance.removeListener(listener);

        expect((created.isNotEmpty, disposed.containsAll(created)), (true, true));
      },
    );

    testWidgets(
      'when scaled text runs in an automated test, it should keep deterministic direct painting',
      (tester) async {
        await tester.pumpWidget(const _RtlTextMorphTestApp());

        await tester.tap(find.byKey(_RtlTextMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final sourceRaster = _retainedTextDiagnostic<ui.Image>(
          tester,
          'retainedTextRaster',
        );
        final sourceText = _retainedTextDiagnostic<String>(
          tester,
          'paintedText',
        );
        final sourceBlocker = _retainedTextDiagnostic<String>(
          tester,
          'rasterRetentionBlocker',
        );
        await tester.pump(const Duration(milliseconds: 40));
        final reusedSourceRaster = _retainedTextDiagnostic<ui.Image>(
          tester,
          'retainedTextRaster',
        );
        await tester.pump(const Duration(milliseconds: 80));
        final destinationRaster = _retainedTextDiagnostic<ui.Image>(
          tester,
          'retainedTextRaster',
        );
        final destinationText = _retainedTextDiagnostic<String>(
          tester,
          'paintedText',
        );
        await tester.pumpAndSettle();

        expect(
          (
            sourceRaster,
            identical(sourceRaster, reusedSourceRaster),
            sourceText,
            destinationRaster,
            destinationText,
          ),
          (null, true, 'מקור', null, 'יעד ארוך'),
          reason: 'source blocker: $sourceBlocker',
        );
      },
    );

    testWidgets(
      'when an automated test paints text, it should skip asynchronous raster preparation',
      (tester) async {
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const _RtlTextMorphTestApp());

        await tester.tap(find.byKey(_RtlTextMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final raster = _retainedTextDiagnostic<ui.Image>(
          tester,
          'retainedTextRaster',
        );
        final rasterDensity = _retainedTextDiagnostic<double>(
          tester,
          'retainedTextRasterDevicePixelRatio',
        );
        final rasterPadding = _retainedTextDiagnostic<double>(
          tester,
          'retainedTextRasterPadding',
        );

        expect(
          (
            raster,
            rasterDensity,
            rasterPadding! > 0,
            _retainedTextDiagnostic<String>(
              tester,
              'rasterRetentionBlocker',
            ),
          ),
          (null, null, false, 'automated test configuration'),
        );
      },
    );

    testWidgets(
      'when an automated reverse flight paints text, it should preserve direct paint math',
      (tester) async {
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 300,
                    child: Text(
                      'Reverse',
                      key: ValueKey('reverse-large'),
                      style: TextStyle(fontSize: 34),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: Text(
                      'Reverse',
                      key: ValueKey('reverse-small'),
                      style: TextStyle(fontSize: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final source = _textProperties(
          tester,
          const ValueKey('reverse-large'),
          switchThreshold: 0.5,
        );
        final destination = _textProperties(
          tester,
          const ValueKey('reverse-small'),
          switchThreshold: 0.5,
        );
        final animation = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 300),
          value: 0.2,
        );
        addTearDown(animation.dispose);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 300,
              height: 80,
              child: _AnimatedMorphTextFlightHarness(
                source: source,
                destination: destination,
                animation: animation,
              ),
            ),
          ),
        );
        final raster = _retainedTextDiagnostic<ui.Image>(
          tester,
          'retainedTextRaster',
        );
        final rasterDensity = _retainedTextDiagnostic<double>(
          tester,
          'retainedTextRasterDevicePixelRatio',
        );

        animation.value = 0.4;
        await tester.pump();
        final reusedRaster = _retainedTextDiagnostic<ui.Image>(
          tester,
          'retainedTextRaster',
        );
        final midpoint = const MorphTextFlightDelegate().lerp(
          source,
          destination,
          0.4,
        );
        await tester.pumpWidget(const SizedBox.shrink());

        final preservedPaintMath =
            midpoint.paintStyle.fontSize == 22 && (midpoint.paintScaleX - (34 + (22 - 34) * 0.4) / 22).abs() < 0.000001;
        expect(
          (
            raster,
            identical(raster, reusedRaster),
            rasterDensity,
            preservedPaintMath,
          ),
          (null, true, null, true),
        );
      },
    );

    testWidgets(
      'when a retained text raster exceeds the safe texture size, it should paint text directly',
      (tester) async {
        tester.view.physicalSize = const Size(20000, 800);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          const _RtlTextMorphTestApp(
            sourceWidth: 10000,
            destinationWidth: 12000,
          ),
        );

        await tester.tap(find.byKey(_RtlTextMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));

        expect(
          (
            _retainedTextDiagnostic<ui.Image>(
              tester,
              'retainedTextRaster',
            ),
            _retainedTextDiagnostic<String>(
              tester,
              'rasterRetentionBlocker',
            ),
            _retainedTextDiagnostic<String>(tester, 'paintedText'),
          ),
          (null, 'raster dimensions', 'מקור'),
        );
      },
    );

    testWidgets(
      'when cached text flies between endpoints, it should preserve endpoint and midpoint semantics ownership',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(const _RtlTextMorphTestApp());
          final sourceSemantics = find.semantics.byLabel('מקור').evaluate().length;

          await tester.tap(find.byKey(_RtlTextMorphTestApp.toggleKey));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));
          final midpointSemantics = (
            find.semantics.byLabel('מקור').evaluate().length,
            find.semantics.byLabel('יעד ארוך').evaluate().length,
          );
          await tester.pumpAndSettle();
          final destinationSemantics = find.semantics.byLabel('יעד ארוך').evaluate().length;

          expect(
            (sourceSemantics, midpointSemantics, destinationSemantics),
            (1, (0, 0), 1),
          );
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'when standalone text advances, it should repaint inside local flight bounds without relayout',
      (tester) async {
        tester.view.physicalSize = const Size(400, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const _RetainedTextGeometryApp());
        await tester.pumpAndSettle();
        final sourceBounds = tester.getRect(
          find.byKey(_RetainedTextGeometryApp.sourceKey),
        );

        await tester.tap(find.byKey(_RetainedTextGeometryApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final destinationBounds = tester.getRect(
          find.byKey(_RetainedTextGeometryApp.destinationKey),
        );
        final overlay = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_MorphOverlay',
        );
        final renderObject = _retainedTextRenderObject(tester);
        final firstLayoutCount = _retainedTextDiagnostic<int>(
          tester,
          'layoutCount',
        );
        final firstPaintBounds = renderObject.paintBounds;

        await tester.pump(const Duration(milliseconds: 40));

        expect(
          (
            find
                .descendant(
                  of: overlay,
                  matching: find.byType(PositionedTransition),
                )
                .evaluate()
                .length,
            renderObject.isRepaintBoundary,
            renderObject.size,
            firstPaintBounds,
            _retainedTextDiagnostic<int>(tester, 'layoutCount'),
          ),
          (
            0,
            true,
            const Size(400, 700),
            Rect.lerp(sourceBounds, destinationBounds, 0.3),
            firstLayoutCount,
          ),
        );
      },
    );

    testWidgets(
      'when retained text repaints, it should interpolate its properties once per progress value',
      (tester) async {
        tester.view.physicalSize = const Size(400, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const _RetainedTextGeometryApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_RetainedTextGeometryApp.toggleKey));
        await tester.pump();
        await tester.pump();
        final before = _retainedTextDiagnostic<int>(
          tester,
          'propertiesInterpolationCount',
        )!;

        await tester.pump(const Duration(milliseconds: 40));
        final afterFrame = _retainedTextDiagnostic<int>(
          tester,
          'propertiesInterpolationCount',
        )!;
        final renderObject = _retainedTextRenderObject(tester);
        for (var index = 0; index < 2; index += 1) {
          renderObject.paintBounds;
        }
        final afterBoundsReads = _retainedTextDiagnostic<int>(
          tester,
          'propertiesInterpolationCount',
        )!;

        expect(
          (afterFrame - before, afterBoundsReads - afterFrame),
          (1, 0),
        );
      },
    );

    testWidgets(
      'when non-wrapping clipped text flies, it should keep one line in the retained painter',
      (tester) async {
        await tester.pumpWidget(
          const _OverflowTextMorphTestApp(overflow: TextOverflow.clip),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_OverflowTextMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final overlay = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_MorphOverlay',
        );

        expect(
          (
            find
                .descendant(
                  of: overlay,
                  matching: find.byType(PositionedTransition),
                )
                .evaluate()
                .length,
            _retainedTextDiagnostic<int>(tester, 'paintedLineCount'),
          ),
          (0, 1),
        );
      },
    );

    testWidgets(
      'when non-wrapping visible text flies, it should retain the native pixels outside its endpoint',
      (tester) async {
        tester.view.physicalSize = const Size(300, 180);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey<String>('visible-text-boundary');
        const text = 'Visible text paints beyond its endpoint';
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
                          width: 70,
                          child: Morph(
                            tag: 'visible-text',
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.linear,
                            child: Text(
                              text,
                              key: ValueKey<String>(
                                'visible-text-$destination',
                              ),
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 20,
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
        final overlay = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_MorphOverlay',
        );
        const overflowRegion = Rect.fromLTRB(90, 15, 295, 65);
        const textRegion = Rect.fromLTRB(15, 15, 295, 70);
        final observed = (
          find
              .descendant(
                of: overlay,
                matching: find.byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_MorphTextFlight',
                ),
              )
              .evaluate()
              .length,
          find
              .descendant(
                of: overlay,
                matching: find.byType(PositionedTransition),
              )
              .evaluate()
              .length,
          _redPixelCount(resting, overflowRegion) > 0,
          _pixelsMatch(resting, flight, textRegion),
        );
        await tester.pumpAndSettle();

        expect(observed, (1, 0, true, true));
      },
    );

    for (final variant in <({TextOverflow overflow, bool hasFadeShader})>[
      (overflow: TextOverflow.fade, hasFadeShader: true),
    ]) {
      testWidgets(
        'when ${variant.overflow.name} text flies, it should use the native overflow renderer',
        (tester) async {
          await tester.pumpWidget(
            _OverflowTextMorphTestApp(overflow: variant.overflow),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(_OverflowTextMorphTestApp.toggleKey));
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120));
          final overlay = find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphOverlay',
          );
          final flightText = find.descendant(
            of: overlay,
            matching: find.text(_OverflowTextMorphTestApp.text),
          );
          final paragraph = tester.renderObject<RenderParagraph>(flightText);

          expect(
            (
              find
                  .descendant(
                    of: overlay,
                    matching: find.byWidgetPredicate(
                      (widget) => widget.runtimeType.toString() == '_MorphTextFlight',
                    ),
                  )
                  .evaluate()
                  .length,
              paragraph.debugHasOverflowShader,
            ),
            (0, variant.hasFadeShader),
          );
        },
      );
    }

    testWidgets(
      'when text is nested in a Column flight, it should build with the stable destination font transform',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: Column(
                      key: ValueKey('source-column'),
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            'Text',
                            style: TextStyle(fontSize: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: Column(
                      key: ValueKey('destination-column'),
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            'Text',
                            style: TextStyle(fontSize: 34),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final sourceFinder = find.byKey(const ValueKey('source-column'));
        final destinationFinder = find.byKey(
          const ValueKey('destination-column'),
        );
        final source = MorphColumnFlightDelegate.captureColumn(
          context: tester.element(sourceFinder),
          column: tester.widget<Column>(sourceFinder),
          renderObject: tester.renderObject<RenderFlex>(sourceFinder),
          axisScale: const Offset(1, 1),
          switchThreshold: 0.5,
        );
        final destination = MorphColumnFlightDelegate.captureColumn(
          context: tester.element(destinationFinder),
          column: tester.widget<Column>(destinationFinder),
          renderObject: tester.renderObject<RenderFlex>(destinationFinder),
          axisScale: const Offset(1, 1),
          switchThreshold: 0.5,
        );
        final midpoint = const MorphColumnFlightDelegate().lerp(
          source,
          destination,
          0.5,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => SizedBox(
                  width: 270,
                  height: 60,
                  child: _MorphColumnPropertiesHarness(
                    properties: midpoint,
                  ),
                ),
              ),
            ),
          ),
        );
        final text = tester.widget<Text>(find.text('Text'));
        final transforms = tester.widgetList<Transform>(find.byType(Transform)).toList();

        expect(
          (
            text.style!.fontSize,
            transforms.any(
              (transform) => (transform.transform.storage[0] - (28 / 34)).abs() < 0.000001,
            ),
          ),
          (34, true),
        );
      },
    );

    testWidgets(
      'when equal-size endpoint text changes, it should retain the selected endpoint layout width',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: Text(
                      'Summary',
                      key: ValueKey('equal-size-summary'),
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: Text(
                      'Full description',
                      key: ValueKey('equal-size-description'),
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final source = _textProperties(
          tester,
          const ValueKey('equal-size-summary'),
          switchThreshold: 0.5,
        );
        final destination = _textProperties(
          tester,
          const ValueKey('equal-size-description'),
          switchThreshold: 0.5,
        );
        const delegate = MorphTextFlightDelegate();

        expect(
          [
            delegate.lerp(source, destination, 0.25).reservedLayoutWidth,
            delegate.lerp(source, destination, 0.75).reservedLayoutWidth,
          ],
          [180, 360],
        );
      },
    );

    testWidgets(
      'when one-line text flies toward a narrower one-line endpoint, it should keep one line until ownership transfers',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 320,
                    child: Text(
                      'Source title stays on one line',
                      key: ValueKey('one-line-wide-source'),
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: Text(
                      'Done',
                      key: ValueKey('one-line-narrow-destination'),
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final source = _textProperties(
          tester,
          const ValueKey('one-line-wide-source'),
          switchThreshold: 0.5,
        );
        final destination = _textProperties(
          tester,
          const ValueKey('one-line-narrow-destination'),
          switchThreshold: 0.5,
        );
        const delegate = MorphTextFlightDelegate();
        final beforeTransfer = delegate.lerp(source, destination, 0.25);
        final afterTransfer = delegate.lerp(source, destination, 0.75);

        int paintedLineCount(MorphTextProperties properties) {
          final painter = TextPainter(
            text: TextSpan(
              text: properties.text,
              style: properties.paintStyle,
            ),
            textAlign: properties.textAlign ?? TextAlign.start,
            textDirection: properties.textDirection,
            textScaler: properties.textScaler,
            locale: properties.locale,
            textWidthBasis: properties.textWidthBasis ?? TextWidthBasis.parent,
            textHeightBehavior: properties.textHeightBehavior,
            strutStyle: properties.strutStyle,
            maxLines: properties.maxLines,
          );
          try {
            painter.layout(maxWidth: properties.reservedLayoutWidth!);
            return painter.computeLineMetrics().length;
          } finally {
            painter.dispose();
          }
        }

        expect(
          (
            source.measuredLineCount,
            destination.measuredLineCount,
            beforeTransfer.reservedLayoutWidth! > destination.layoutWidth,
            paintedLineCount(beforeTransfer),
            afterTransfer.reservedLayoutWidth,
            paintedLineCount(afterTransfer),
          ),
          (1, 1, true, 1, 140, 1),
        );
      },
    );

    testWidgets(
      'when equal-size text transfers between identical widths, it should retain the common layout width',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 240,
                    child: Text(
                      'Source',
                      key: ValueKey('common-width-source'),
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: Text(
                      'A much longer destination string',
                      key: ValueKey('common-width-destination'),
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final source = _textProperties(
          tester,
          const ValueKey('common-width-source'),
          switchThreshold: 0.5,
        );
        final destination = _textProperties(
          tester,
          const ValueKey('common-width-destination'),
          switchThreshold: 0.5,
        );

        expect(
          const MorphTextFlightDelegate().lerp(source, destination, 0.75).reservedLayoutWidth,
          240,
        );
      },
    );

    testWidgets(
      'when an optimized right-to-left flight uses longest-line width, it should keep its right edge anchored',
      (tester) async {
        await tester.pumpWidget(const _RtlTextMorphTestApp());
        final sourceRight = tester
            .getTopRight(
              find.byWidgetPredicate(
                (widget) => widget is Morph,
              ),
            )
            .dx;
        await tester.tap(find.byKey(_RtlTextMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        final flight =
            find
                    .descendant(
                      of: find.byWidgetPredicate(
                        (widget) => widget.runtimeType.toString() == '_MorphOverlay',
                      ),
                      matching: find.byWidgetPredicate(
                        (widget) => widget.runtimeType.toString() == '_MorphTextFlight',
                      ),
                    )
                    .evaluate()
                    .single
                    .renderObject!
                as RenderBox;
        expect(
          flight.localToGlobal(Offset(flight.size.width, 0)).dx,
          closeTo(sourceRight, 0.001),
        );
      },
    );

    testWidgets(
      'when multiline text transfers to a one-line endpoint, it should switch the paragraph boundary atomically',
      (tester) async {
        const description =
            'A long description that needs several lines at this width so the '
            'flight can progressively remove lines while returning to its summary.';
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(description, key: ValueKey('full')),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      description,
                      key: ValueKey('summary'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final source = _textProperties(
          tester,
          const ValueKey('full'),
          switchThreshold: 0.8,
        );
        final destination = _textProperties(
          tester,
          const ValueKey('summary'),
          switchThreshold: 0.5,
        );
        const delegate = MorphTextFlightDelegate(switchThreshold: 0.8);
        final early = delegate.lerp(source, destination, 0.1);
        final beforeTransfer = delegate.lerp(source, destination, 0.6);
        final afterTransfer = delegate.lerp(source, destination, 0.8);

        expect(
          (
            early.maxLines,
            beforeTransfer.maxLines,
            beforeTransfer.overflow,
            afterTransfer.maxLines,
            afterTransfer.overflow,
          ),
          (null, null, TextOverflow.clip, 1, TextOverflow.ellipsis),
        );
      },
    );
  });

  group('Morph Text switchThreshold', () {
    for (final threshold in [0.0, 0.2, 0.5, 0.8, 1.0]) {
      test(
        'when creating with switchThreshold $threshold, it should not throw',
        () {
          expect(
            () => Morph(
              tag: 'threshold',
              switchThreshold: threshold,
              child: const Text('Text'),
            ),
            returnsNormally,
          );
        },
      );
    }

    test(
      'when creating with switchThreshold below zero, it should throw an assertion error',
      () {
        expect(
          () => Morph(
            tag: 'threshold',
            switchThreshold: -0.1,
            child: const Text('Text'),
          ),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test(
      'when creating with switchThreshold above one, it should throw an assertion error',
      () {
        expect(
          () => Morph(
            tag: 'threshold',
            switchThreshold: 1.5,
            child: const Text('Text'),
          ),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    testWidgets(
      'when building with a custom switchThreshold, it should display the text',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Morph(
                tag: 'custom-threshold',
                switchThreshold: 0.8,
                child: Text('Custom threshold'),
              ),
            ),
          ),
        );

        expect(find.text('Custom threshold'), findsOneWidget);
      },
    );
  });
}

class _RtlTextMorphTestApp extends StatefulWidget {
  const _RtlTextMorphTestApp({
    this.sourceWidth = 180,
    this.destinationWidth = 300,
  });

  static const ValueKey<String> toggleKey = ValueKey('toggle-rtl-text');

  final double sourceWidth;

  final double destinationWidth;

  @override
  State<_RtlTextMorphTestApp> createState() => _RtlTextMorphTestAppState();
}

class _RetainedTextGeometryApp extends StatefulWidget {
  const _RetainedTextGeometryApp();

  static const sourceKey = ValueKey<String>('retained-text-source');
  static const destinationKey = ValueKey<String>(
    'retained-text-destination',
  );
  static const toggleKey = ValueKey<String>('retained-text-toggle');

  @override
  State<_RetainedTextGeometryApp> createState() {
    return _RetainedTextGeometryAppState();
  }
}

class _RetainedTextGeometryAppState extends State<_RetainedTextGeometryApp> {
  bool _destination = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Align(
              alignment: _destination ? Alignment.bottomRight : Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: _destination ? 240 : 120,
                  child: Morph(
                    tag: 'retained-text-geometry',
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.linear,
                    child: Text(
                      _destination ? 'Destination text' : 'Source',
                      key: _destination ? _RetainedTextGeometryApp.destinationKey : _RetainedTextGeometryApp.sourceKey,
                      style: TextStyle(
                        fontSize: _destination ? 34 : 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FilledButton(
                key: _RetainedTextGeometryApp.toggleKey,
                onPressed: () {
                  setState(() => _destination = !_destination);
                },
                child: const Text('Toggle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverflowTextMorphTestApp extends StatefulWidget {
  const _OverflowTextMorphTestApp({required this.overflow});

  static const text = 'Non-wrapping overflow text that is much wider than its endpoint';
  static const toggleKey = ValueKey<String>('overflow-text-toggle');

  final TextOverflow overflow;

  @override
  State<_OverflowTextMorphTestApp> createState() {
    return _OverflowTextMorphTestAppState();
  }
}

class _OverflowTextMorphTestAppState extends State<_OverflowTextMorphTestApp> {
  bool _destination = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: _destination ? 140 : 100,
                child: Morph(
                  tag: 'overflow-text-${widget.overflow.name}',
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.linear,
                  child: Text(
                    _OverflowTextMorphTestApp.text,
                    softWrap: false,
                    overflow: widget.overflow,
                    style: TextStyle(
                      fontSize: _destination ? 30 : 18,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FilledButton(
                key: _OverflowTextMorphTestApp.toggleKey,
                onPressed: () {
                  setState(() => _destination = !_destination);
                },
                child: const Text('Toggle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RtlTextMorphTestAppState extends State<_RtlTextMorphTestApp> {
  bool _destination = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Stack(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: SizedBox(
                  width: _destination ? widget.destinationWidth : widget.sourceWidth,
                  child: Morph(
                    tag: 'rtl-text',
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.linear,
                    child: Text(
                      _destination ? 'יעד ארוך' : 'מקור',
                      textWidthBasis: TextWidthBasis.longestLine,
                      style: TextStyle(fontSize: _destination ? 34 : 22),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: FilledButton(
                  key: _RtlTextMorphTestApp.toggleKey,
                  onPressed: () {
                    setState(() => _destination = !_destination);
                  },
                  child: const Text('Toggle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
