import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/morph/morph.dart' show MorphColumnFlightDelegate;

Finder _columnMorphOverlay() {
  return find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_MorphOverlay',
  );
}

Finder _hybridColumnFlight() {
  return find.descendant(
    of: _columnMorphOverlay(),
    matching: find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_MorphHybridColumnRenderWidget',
    ),
  );
}

Rect _hybridColumnDebugRect(
  WidgetTester tester,
  String name,
) {
  return tester
          .renderObject<RenderBox>(_hybridColumnFlight())
          .toDiagnosticsNode()
          .getProperties()
          .singleWhere((property) => property.name == name)
          .value!
      as Rect;
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

Rect _retainedPaintBounds(WidgetTester tester) {
  final renderObject = tester.renderObject<RenderBox>(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_MorphCompoundFlight',
    ),
  );
  return renderObject
          .toDiagnosticsNode()
          .getProperties()
          .singleWhere((property) => property.name == 'paintBounds')
          .value!
      as Rect;
}

({double baseline, int paintedLineCount, Rect rect, Text widget}) _columnFlightText(
  WidgetTester tester,
  String text,
) {
  final elements = find
      .descendant(
        of: _columnMorphOverlay(),
        matching: find.text(text, skipOffstage: false),
      )
      .evaluate();
  if (elements.isNotEmpty) {
    final element = elements.single;
    final renderBox = element.renderObject! as RenderBox;
    final widget = element.widget as Text;
    final painter = TextPainter(
      text: TextSpan(text: widget.data, style: widget.style),
      textAlign: widget.textAlign ?? TextAlign.start,
      textDirection: widget.textDirection ?? TextDirection.ltr,
      textScaler: widget.textScaler ?? TextScaler.noScaling,
      maxLines: widget.maxLines,
      ellipsis: widget.overflow == TextOverflow.ellipsis ? '…' : null,
    );
    try {
      painter.layout(maxWidth: renderBox.size.width);
      final rect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
      return (
        baseline: rect.top + painter.computeLineMetrics().first.baseline,
        paintedLineCount: painter.computeLineMetrics().length,
        rect: rect,
        widget: widget,
      );
    } finally {
      painter.dispose();
    }
  }

  final layout = _retainedTextLayouts(
    tester,
  ).singleWhere((layout) => layout['text'] == text);
  return (
    baseline: layout['baseline']! as double,
    paintedLineCount: layout['paintedLineCount']! as int,
    rect: layout['rect']! as Rect,
    widget: Text(
      layout['text']! as String,
      style: layout['style']! as TextStyle,
      textDirection: layout['textDirection']! as TextDirection,
      textScaler: layout['textScaler']! as TextScaler,
      maxLines: layout['maxLines'] as int?,
      overflow: layout['overflow'] as TextOverflow?,
    ),
  );
}

int _paintedLineCount(
  ({double baseline, int paintedLineCount, Rect rect, Text widget}) entry,
) {
  return entry.paintedLineCount;
}

int _columnFlightTextCount(WidgetTester tester, String text) {
  final widgetCount = find
      .descendant(
        of: _columnMorphOverlay(),
        matching: find.text(text, skipOffstage: false),
      )
      .evaluate()
      .length;
  if (widgetCount != 0) return widgetCount;
  return _retainedTextLayouts(
    tester,
  ).where((layout) => layout['text'] == text).length;
}

Object? _retainedTextRaster(WidgetTester tester, String text) {
  return _retainedTextLayouts(tester).singleWhere(
    (layout) => layout['text'] == text,
  )['raster'];
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

void main() {
  group('Morph Column', () {
    test('when no curve is provided, it should defer curve resolution', () {
      const morph = Morph(tag: 'default-curve', child: Column());

      expect(morph.curve, isNull);
    });

    testWidgets(
      'when built at rest, it should lay out children vertically and reserve bounded width',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: Morph(
                  tag: 'resting-column',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text('First'), Text('Second')],
                  ),
                ),
              ),
            ),
          ),
        );

        final morph = find.byWidgetPredicate((widget) => widget is Morph);
        expect(
          (
            tester.getTopLeft(find.text('Second')).dy > tester.getTopLeft(find.text('First')).dy,
            tester.getSize(morph).width,
          ),
          (true, 300),
        );
      },
    );

    testWidgets(
      'when keyed and positional children move, it should settle in destination order',
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
                    tag: 'column',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: destination
                          ? const [
                              Text('Payment'),
                              Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text('Title', key: ValueKey('title')),
                              ),
                              Text('Description'),
                            ]
                          : const [
                              Text('Title', key: ValueKey('title')),
                              Text('Payment'),
                            ],
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

        expect(find.text('Description'), findsOneWidget);
      },
    );

    testWidgets(
      'when Motion wraps a keyed Text, it should Morph the Text to its matched Column position',
      (tester) async {
        const descriptionKey = ValueKey<String>('job_description');
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
                      tag: 'motion-wrapped-column-text',
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.linear,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (destination)
                            const Motion(
                              effect: FadeInMotionEffect(),
                              child: Text(
                                'Full job description',
                                key: descriptionKey,
                              ),
                            )
                          else
                            const Padding(
                              key: descriptionKey,
                              padding: EdgeInsets.only(top: 4),
                              child: Text('Job description summary'),
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
        final sourceRect = tester.getRect(
          find.text('Job description summary'),
        );

        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        final destinationRect = tester.getRect(
          find.text('Full job description'),
        );
        await tester.pump(const Duration(milliseconds: 200));
        final retainedLayouts = _retainedTextLayouts(tester);
        final flightRect = retainedLayouts.single['rect']! as Rect;

        expect(
          (
            retainedLayouts.length,
            flightRect.topLeft,
            find
                .descendant(
                  of: _columnMorphOverlay(),
                  matching: find.byWidgetPredicate(
                    (widget) => widget.runtimeType.toString() == '_MorphColumnFlight',
                  ),
                )
                .evaluate()
                .length,
          ),
          (1, Rect.lerp(sourceRect, destinationRect, 0.5)!.topLeft, 0),
          reason: 'source=$sourceRect destination=$destinationRect flight=$flightRect',
        );
      },
    );

    testWidgets(
      'when an unsupported child uses a SizedBox wrapper, it should preserve the measured size during flight',
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
                      tag: 'sized-wrapper-flight',
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.linear,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            key: const ValueKey('sized-wrapper'),
                            width: destination ? 80 : 40,
                            height: destination ? 60 : 20,
                            child: const ColoredBox(
                              key: ValueKey('sized-content'),
                              color: Colors.green,
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
        await tester.pump(const Duration(milliseconds: 200));
        final content = find.descendant(
          of: _columnMorphOverlay(),
          matching: find.byKey(const ValueKey('sized-content')),
        );

        expect(tester.getSize(content), const Size(60, 40));
      },
    );

    testWidgets(
      'when a Column contains an unsupported ParentData child, it should skip or switch it without an exception',
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
                    child: SizedBox(
                      width: 160,
                      height: 120,
                      child: Morph(
                        tag: 'expanded-column-child',
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.linear,
                        child: Column(
                          children: [
                            Expanded(
                              key: const ValueKey('expanded-child'),
                              child: ColoredBox(
                                color: destination ? Colors.blue : Colors.red,
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
        final diagnostic = tester.takeException();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(
          (
            diagnostic,
            tester.takeException(),
            _columnMorphOverlay().evaluate().length,
          ),
          (null, null, 1),
        );
      },
    );

    testWidgets(
      'when a keyed Column flight advances, it should reuse its child match plan',
      (tester) async {
        final sourceKeys = [
          for (var index = 0; index < 24; index += 1) _CountingKey(index),
        ];
        final destinationKeys = [
          for (var index = 0; index < 24; index += 1) _CountingKey(index),
        ];
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            builder: ({required destination}) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var offset = 0; offset < 24; offset += 1)
                  Text(
                    'Child ${destination ? 23 - offset : offset}',
                    key: destination ? destinationKeys[23 - offset] : sourceKeys[offset],
                  ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        _columnMorphOverlay().evaluate().single;
        _CountingKey.comparisons = 0;
        for (var frame = 0; frame < 3; frame += 1) {
          await tester.pump(const Duration(milliseconds: 40));
        }

        expect(_CountingKey.comparisons, 0);
      },
    );

    testWidgets(
      'when retained Column text is queried repeatedly at one progress, it should interpolate properties once',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            builder: ({required destination}) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cached interpolation',
                  style: TextStyle(fontSize: destination ? 34 : 22),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final layout = _retainedTextLayouts(tester).singleWhere(
          (layout) => layout['text'] == 'Cached interpolation',
        );

        expect(layout['interpolationsAtProgress'], 1);
      },
    );

    testWidgets(
      'when scaled Column text keeps a stable paragraph, it should reuse and dispose its retained raster',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            builder: ({required destination}) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Retained title',
                  style: TextStyle(fontSize: destination ? 34 : 22),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final raster = _retainedTextRaster(tester, 'Retained title');
        await tester.pump(const Duration(milliseconds: 40));
        final reusedRaster = _retainedTextRaster(
          tester,
          'Retained title',
        );
        final reused = identical(raster, reusedRaster);

        await tester.pumpAndSettle();

        expect(
          (raster, reusedRaster, reused),
          (null, null, true),
        );
      },
    );

    testWidgets(
      'when Column text changes only solid color and height, it should remain raster eligible',
      (tester) async {
        const text = 'Changing style';
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            builder: ({required destination}) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: destination ? Colors.blue : Colors.red,
                    fontSize: destination ? 34 : 22,
                    height: destination ? 1.1 : 1.3,
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final layout = _retainedTextLayouts(
          tester,
        ).singleWhere((layout) => layout['text'] == text);

        expect(
          (
            layout['raster'],
            layout['rasterRetentionBlocker'],
            (layout['style']! as TextStyle).color,
          ),
          (
            null,
            'automated test configuration',
            Color.lerp(Colors.red, Colors.blue, 0.5),
          ),
        );
      },
    );

    testWidgets(
      'when Column text changes another style property, it should keep the direct text fallback',
      (tester) async {
        const text = 'Changing letter spacing';
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            builder: ({required destination}) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: destination ? Colors.blue : Colors.red,
                    fontSize: destination ? 34 : 22,
                    height: destination ? 1.1 : 1.3,
                    letterSpacing: destination ? 1 : 0,
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final layout = _retainedTextLayouts(
          tester,
        ).singleWhere((layout) => layout['text'] == text);

        expect(
          (layout['raster'], layout['rasterRetentionBlocker']),
          (null, 'different endpoint style'),
        );
      },
    );

    testWidgets(
      'when source and destination child counts differ, it should transfer the shared children safely',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            builder: ({required destination}) => Column(
              mainAxisSize: MainAxisSize.min,
              children: destination ? const [Text('Hello'), Text('Hola')] : const [Text('Hello')],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final exception = tester.takeException();
        await tester.pumpAndSettle();

        expect(
          (exception, find.text('Hola').evaluate().length),
          (null, 1),
        );
      },
    );

    testWidgets(
      'when the switch threshold is reached, it should remove the departing child',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            switchThreshold: 0.25,
            builder: ({required destination}) => Column(
              mainAxisSize: MainAxisSize.min,
              children: destination
                  ? const [
                      Text('Shared', key: ValueKey('shared-child')),
                      Text('Arriving', key: ValueKey('arriving-child')),
                    ]
                  : const [
                      Text('Shared', key: ValueKey('shared-child')),
                      Text('Departing', key: ValueKey('departing-child')),
                    ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final beforeThreshold = _columnFlightTextCount(
          tester,
          'Departing',
        );
        await tester.pump(const Duration(milliseconds: 40));
        final afterThreshold = _columnFlightTextCount(
          tester,
          'Departing',
        );

        expect((beforeThreshold, afterThreshold), (1, 0));
      },
    );

    testWidgets(
      'when progress is zero with an immediate switch threshold, it should retain the complete source properties',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: Column(
                      key: ValueKey('zero-source-column'),
                      children: [
                        Text('Shared', key: ValueKey('zero-shared')),
                        Text('Departing', key: ValueKey('zero-departing')),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: Column(
                      key: ValueKey('zero-destination-column'),
                      children: [
                        Text('Shared', key: ValueKey('zero-shared')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final sourceFinder = find.byKey(
          const ValueKey('zero-source-column'),
        );
        final destinationFinder = find.byKey(
          const ValueKey('zero-destination-column'),
        );
        final source = MorphColumnFlightDelegate.captureColumn(
          context: tester.element(sourceFinder),
          column: tester.widget<Column>(sourceFinder),
          renderObject: tester.renderObject<RenderFlex>(sourceFinder),
          axisScale: const Offset(1, 1),
          switchThreshold: 0,
        );
        final destination = MorphColumnFlightDelegate.captureColumn(
          context: tester.element(destinationFinder),
          column: tester.widget<Column>(destinationFinder),
          renderObject: tester.renderObject<RenderFlex>(destinationFinder),
          axisScale: const Offset(1, 1),
          switchThreshold: 0,
        );

        expect(
          identical(
            const MorphColumnFlightDelegate(
              switchThreshold: 0,
            ).lerp(source, destination, 0),
            source,
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'when the switch threshold is reached, it should add the arriving child',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            switchThreshold: 0.75,
            builder: ({required destination}) => Column(
              mainAxisSize: MainAxisSize.min,
              children: destination
                  ? const [
                      Text('Shared', key: ValueKey('shared-child')),
                      Text('Arriving', key: ValueKey('arriving-child')),
                    ]
                  : const [
                      Text('Shared', key: ValueKey('shared-child')),
                      Text('Departing', key: ValueKey('departing-child')),
                    ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 280));
        final beforeThreshold = _columnFlightTextCount(
          tester,
          'Arriving',
        );
        await tester.pump(const Duration(milliseconds: 40));
        final afterThreshold = _columnFlightTextCount(
          tester,
          'Arriving',
        );

        expect((beforeThreshold, afterThreshold), (0, 1));
      },
    );

    testWidgets(
      'when ordinary unmatched descendants use a transition, it should animate their departure and arrival',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            switchThreshold: 0.5,
            switchTransition: (child, animation) {
              return FadeTransition(
                key: const ValueKey('column-ordinary-transition'),
                opacity: animation,
                child: child,
              );
            },
            builder: ({required destination}) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  key: ValueKey(
                    destination ? 'arriving-ordinary-column-child' : 'departing-ordinary-column-child',
                  ),
                  builder: (context) => const SizedBox.square(
                    dimension: 24,
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final departingOpacity = tester
            .widget<FadeTransition>(
              find.descendant(
                of: _columnMorphOverlay(),
                matching: find.byKey(
                  const ValueKey('column-ordinary-transition'),
                ),
              ),
            )
            .opacity
            .value;

        await tester.pump(const Duration(milliseconds: 300));
        final arrivingOpacity = tester
            .widget<FadeTransition>(
              find.descendant(
                of: _columnMorphOverlay(),
                matching: find.byKey(
                  const ValueKey('column-ordinary-transition'),
                ),
              ),
            )
            .opacity
            .value;

        expect(
          (
            (departingOpacity - 0.75).abs() < 1e-9,
            (arrivingOpacity - 0.75).abs() < 1e-9,
          ),
          (true, true),
        );
      },
    );

    testWidgets(
      'when a retained Column contains raw islands, it should retain each selected subtree around the switch threshold',
      (tester) async {
        var rawBuilds = 0;
        var transitionBuilds = 0;
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            switchThreshold: 0.5,
            switchTransition: (child, animation) {
              transitionBuilds += 1;
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            builder: ({required destination}) => Column(
              children: [
                const Text(
                  'Hybrid retained title',
                  key: ValueKey('hybrid-retained-title'),
                ),
                Container(
                  key: const ValueKey('hybrid-retained-surface'),
                  padding: const EdgeInsets.all(8),
                  color: destination ? Colors.blue : Colors.red,
                  child: const Text(
                    'Hybrid retained surface text',
                    key: ValueKey('hybrid-retained-surface-text'),
                  ),
                ),
                Builder(
                  key: ValueKey(
                    destination ? 'retained-raw-arrival' : 'retained-raw-departure',
                  ),
                  builder: (context) {
                    rawBuilds += 1;
                    return const SizedBox.square(dimension: 32);
                  },
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        final buildsAtStart = (rawBuilds, transitionBuilds);
        final hybridRender = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_MorphHybridColumnRenderWidget',
        );
        int layoutCount() {
          return tester
                  .renderObject<RenderBox>(hybridRender)
                  .toDiagnosticsNode()
                  .getProperties()
                  .singleWhere((property) => property.name == 'layoutCount')
                  .value!
              as int;
        }

        final layoutsAtStart = layoutCount();
        final retainedTexts =
            (tester
                        .renderObject<RenderBox>(hybridRender)
                        .toDiagnosticsNode()
                        .getProperties()
                        .singleWhere(
                          (property) => property.name == 'retainedTextLayouts',
                        )
                        .value!
                    as List<Object?>)
                .cast<Map<String, Object?>>()
                .map((layout) => layout['text'])
                .toSet();
        await tester.pump(const Duration(milliseconds: 40));
        await tester.pump(const Duration(milliseconds: 40));
        final buildsBeforeDeparture = (rawBuilds, transitionBuilds);
        final layoutsBeforeDeparture = layoutCount();
        await tester.pump(const Duration(milliseconds: 80));
        final buildsBeforeArrival = (rawBuilds, transitionBuilds);
        await tester.pump(const Duration(milliseconds: 80));
        final buildsAfterArrival = (rawBuilds, transitionBuilds);

        expect(
          (
            find
                .descendant(
                  of: _columnMorphOverlay(),
                  matching: find.byWidgetPredicate(
                    (widget) => widget.runtimeType.toString() == '_MorphHybridColumnFlight',
                  ),
                )
                .evaluate()
                .length,
            buildsBeforeDeparture == buildsAtStart,
            buildsBeforeArrival == buildsAtStart,
            buildsAfterArrival.$1 == buildsAtStart.$1 + 1,
            buildsAfterArrival.$2 == buildsAtStart.$2 + 1,
            layoutsBeforeDeparture == layoutsAtStart,
            retainedTexts.containsAll(const {
              'Hybrid retained title',
              'Hybrid retained surface text',
            }),
            find
                .descendant(
                  of: _columnMorphOverlay(),
                  matching: find.byKey(
                    const ValueKey('hybrid-retained-surface'),
                  ),
                )
                .evaluate()
                .length,
          ),
          (1, true, true, true, true, true, true, 0),
        );
      },
    );

    testWidgets(
      'when a hybrid raw slot changes size continuously, it should not add an inner repaint boundary',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            sourceWidth: 100,
            destinationWidth: 200,
            builder: ({required destination}) => Column(
              children: [
                Builder(
                  key: const ValueKey('changing-hybrid-raw-builder'),
                  builder: (context) => SizedBox.square(
                    dimension: destination ? 200 : 100,
                    child: const ColoredBox(
                      key: ValueKey('changing-hybrid-raw'),
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        final rawSlot = find.descendant(
          of: _columnMorphOverlay(),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphHybridRawSlot',
          ),
        );

        expect(
          find.descendant(of: rawSlot, matching: find.byType(RepaintBoundary)),
          findsNothing,
        );
      },
    );

    testWidgets(
      'when a hybrid raw slot keeps the same size, it should retain its inner repaint boundary',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            sourceWidth: 100,
            destinationWidth: 200,
            builder: ({required destination}) => Column(
              children: [
                Builder(
                  key: const ValueKey('stable-hybrid-raw-builder'),
                  builder: (context) => const SizedBox.square(
                    dimension: 100,
                    child: ColoredBox(
                      key: ValueKey('stable-hybrid-raw'),
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final rawSlot = find.descendant(
          of: _columnMorphOverlay(),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphHybridRawSlot',
          ),
        );

        expect(
          find.descendant(of: rawSlot, matching: find.byType(RepaintBoundary)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'when retained reflow moves a hybrid raw child beyond the root bounds, it should include the clipped child rect in paint bounds',
      (tester) async {
        const rawKey = ValueKey('reflowed-hybrid-raw');
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            sourceWidth: 110,
            destinationWidth: 110,
            builder: ({required destination}) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 110,
                  height: 18,
                  child: Text(
                    'This retained text wraps well below its deliberately short layout box.',
                    overflow: TextOverflow.visible,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
                Builder(
                  key: const ValueKey('reflowed-hybrid-raw-builder'),
                  builder: (context) => SizedBox(
                    key: rawKey,
                    width: 24,
                    height: 24,
                    child: ColoredBox(
                      color: destination ? Colors.blue : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final flightTop = tester.getTopLeft(_hybridColumnFlight()).dy;
        final rawBottom = tester
            .getRect(
              find.descendant(
                of: _columnMorphOverlay(),
                matching: find.byKey(rawKey),
              ),
            )
            .bottom;
        final paintBounds = _hybridColumnDebugRect(tester, 'paintBounds');

        expect(paintBounds.bottom, rawBottom - flightTop);
      },
    );

    testWidgets(
      'when an extreme curve overshoots hybrid Column geometry, it should extrapolate positive sizes and collapse negative sizes safely',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            sourceWidth: 100,
            destinationWidth: 200,
            curve: const _ExtremeHybridOvershootCurve(),
            builder: ({required destination}) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  key: const ValueKey('overshoot-hybrid-raw-builder'),
                  builder: (context) => SizedBox.square(
                    dimension: destination ? 200 : 100,
                    child: ColoredBox(
                      key: ValueKey('overshoot-hybrid-raw-$destination'),
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final rawSlot = find.descendant(
          of: _columnMorphOverlay(),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphHybridRawSlot',
          ),
        );
        final collapsed = (
          tester.getSize(rawSlot),
          _hybridColumnDebugRect(tester, 'flightBounds'),
          _hybridColumnDebugRect(tester, 'paintBounds'),
          tester.takeException(),
        );

        await tester.pump(const Duration(milliseconds: 50));
        final expanded = (
          tester.getSize(rawSlot),
          _hybridColumnDebugRect(tester, 'flightBounds'),
          tester.takeException(),
        );

        expect(
          (collapsed, expanded),
          (
            (Size.zero, Rect.zero, Rect.zero, null),
            (
              const Size.square(300),
              const Rect.fromLTWH(0, 0, 300, 300),
              null,
            ),
          ),
        );
      },
    );

    testWidgets(
      'when raw islands cross the switch threshold, it should preserve their exact endpoint layout and ownership',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            switchThreshold: 0.5,
            builder: ({required destination}) => Column(
              children: [
                SizedBox(
                  key: ValueKey(
                    destination ? 'raw-threshold-arrival-wrapper' : 'raw-threshold-departure-wrapper',
                  ),
                  width: destination ? 80 : 40,
                  height: destination ? 50 : 30,
                  child: ColoredBox(
                    key: ValueKey(
                      destination ? 'raw-threshold-arrival' : 'raw-threshold-departure',
                    ),
                    color: destination ? Colors.blue : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sourceSize = tester.getSize(
          find.byKey(const ValueKey('raw-threshold-departure')),
        );

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        final sourceInOverlay = find.descendant(
          of: _columnMorphOverlay(),
          matching: find.byKey(
            const ValueKey('raw-threshold-departure'),
          ),
        );
        final preThresholdSize = tester.getSize(sourceInOverlay);
        await tester.pump(const Duration(milliseconds: 20));
        final sourceAtThreshold = sourceInOverlay.evaluate().length;
        await tester.pump(const Duration(milliseconds: 20));
        final sourceAfterThreshold = sourceInOverlay.evaluate().length;
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pump(const Duration(milliseconds: 1));
        final destinationInOverlay = find.descendant(
          of: _columnMorphOverlay(),
          matching: find.byKey(
            const ValueKey('raw-threshold-arrival'),
          ),
        );
        final destinationAtThreshold = destinationInOverlay.evaluate().length;
        final destinationFlightSize = tester.getSize(
          destinationInOverlay,
        );
        await tester.pumpAndSettle();
        final destinationSize = tester.getSize(
          find.byKey(const ValueKey('raw-threshold-arrival')),
        );

        expect(
          (
            sourceSize,
            preThresholdSize,
            sourceAtThreshold,
            sourceAfterThreshold,
            destinationAtThreshold,
            destinationFlightSize,
            destinationSize,
          ),
          (
            const Size(40, 30),
            const Size(40, 30),
            1,
            0,
            1,
            const Size(80, 50),
            const Size(80, 50),
          ),
        );
      },
    );

    testWidgets(
      'when matched raw islands have endpoint inheritance, it should switch captured Theme and MediaQuery together',
      (tester) async {
        var destination = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  final inheritedColor = destination ? Colors.blue : Colors.red;
                  return KeyedSubtree(
                    key: ValueKey('inherited-endpoint-$destination'),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.fromSeed(
                          seedColor: inheritedColor,
                          primary: inheritedColor,
                        ),
                      ),
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          padding: EdgeInsets.only(
                            top: destination ? 44 : 12,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: 160,
                            height: 120,
                            child: Morph(
                              tag: 'inherited-hybrid-column',
                              duration: const Duration(
                                milliseconds: 400,
                              ),
                              curve: Curves.linear,
                              child: Column(
                                children: [
                                  SizedBox(
                                    key: const ValueKey(
                                      'inherited-raw-wrapper',
                                    ),
                                    width: 100,
                                    height: 80,
                                    child: Builder(
                                      key: const ValueKey(
                                        'inherited-raw-builder',
                                      ),
                                      builder: (context) {
                                        return ColoredBox(
                                          key: const ValueKey(
                                            'inherited-raw-color',
                                          ),
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          child: const SafeArea(
                                            bottom: false,
                                            child: SizedBox.expand(
                                              key: ValueKey(
                                                'inherited-safe-area-content',
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
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
        final hybridFlight = find.descendant(
          of: _columnMorphOverlay(),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphHybridColumnRenderWidget',
          ),
        );
        final content = find.descendant(
          of: _columnMorphOverlay(),
          matching: find.byKey(
            const ValueKey('inherited-safe-area-content'),
          ),
        );
        final sourceTop = tester.getTopLeft(content).dy - tester.getTopLeft(hybridFlight).dy;
        final sourceColor = tester
            .widget<ColoredBox>(
              find.descendant(
                of: _columnMorphOverlay(),
                matching: find.byKey(
                  const ValueKey('inherited-raw-color'),
                ),
              ),
            )
            .color;
        await tester.pump(const Duration(milliseconds: 200));
        final destinationTop = tester.getTopLeft(content).dy - tester.getTopLeft(hybridFlight).dy;
        final destinationColor = tester
            .widget<ColoredBox>(
              find.descendant(
                of: _columnMorphOverlay(),
                matching: find.byKey(
                  const ValueKey('inherited-raw-color'),
                ),
              ),
            )
            .color;

        expect(
          (
            sourceTop,
            sourceColor,
            destinationTop,
            destinationColor,
          ),
          (12, Colors.red, 44, Colors.blue),
        );
      },
    );

    testWidgets(
      'when a hybrid raw island reverses across ownership, it should keep only one selected subtree mounted',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            switchTransition: (child, animation) {
              return FadeTransition(
                key: const ValueKey('reversing-raw-transition'),
                opacity: animation,
                child: child,
              );
            },
            builder: ({required destination}) => Column(
              children: [
                Builder(
                  key: const ValueKey('reversing-raw-island'),
                  builder: (context) => Text(
                    destination ? 'Reversing destination raw' : 'Reversing source raw',
                    key: ValueKey(
                      destination ? 'reversing-destination-raw' : 'reversing-source-raw',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));
        final destinationAtFortyPercent = find
            .descendant(
              of: _columnMorphOverlay(),
              matching: find.byKey(
                const ValueKey('reversing-destination-raw'),
              ),
            )
            .evaluate()
            .length;
        final ownerCountAtFortyPercent =
            find
                .descendant(
                  of: _columnMorphOverlay(),
                  matching: find.byKey(
                    const ValueKey('reversing-source-raw'),
                  ),
                )
                .evaluate()
                .length +
            destinationAtFortyPercent;
        await tester.pump(const Duration(milliseconds: 40));
        final sourceAtThreshold = find
            .descendant(
              of: _columnMorphOverlay(),
              matching: find.byKey(
                const ValueKey('reversing-source-raw'),
              ),
            )
            .evaluate()
            .length;
        final destinationAtThreshold = find
            .descendant(
              of: _columnMorphOverlay(),
              matching: find.byKey(
                const ValueKey('reversing-destination-raw'),
              ),
            )
            .evaluate()
            .length;
        await tester.pump(const Duration(milliseconds: 40));
        final sourceAfterThreshold = find
            .descendant(
              of: _columnMorphOverlay(),
              matching: find.byKey(
                const ValueKey('reversing-source-raw'),
              ),
            )
            .evaluate()
            .length;

        expect(
          (
            destinationAtFortyPercent,
            ownerCountAtFortyPercent,
            sourceAtThreshold,
            destinationAtThreshold,
            sourceAfterThreshold,
          ),
          (1, 1, 1, 0, 1),
        );
      },
    );

    testWidgets(
      'when a matched raw island changes its peeled wrappers, it should keep the interpolating widget fallback',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            builder: ({required destination}) => Column(
              children: [
                Padding(
                  key: const ValueKey('changing-raw-wrapper'),
                  padding: EdgeInsets.all(destination ? 24 : 4),
                  child: SizedBox.square(
                    dimension: destination ? 40 : 20,
                    child: const ColoredBox(
                      key: ValueKey('changing-raw-content'),
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final overlay = _columnMorphOverlay();
        final fallback = find.descendant(
          of: overlay,
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphColumnFlight',
          ),
        );
        final interpolatedPadding = find.descendant(
          of: overlay,
          matching: find.byWidgetPredicate(
            (widget) => widget is Padding && widget.padding == const EdgeInsets.all(14),
          ),
        );
        final interpolatedSize = find.descendant(
          of: overlay,
          matching: find.byWidgetPredicate(
            (widget) => widget is SizedBox && widget.width == 30 && widget.height == 30,
          ),
        );

        expect(
          (
            find
                .descendant(
                  of: overlay,
                  matching: find.byWidgetPredicate(
                    (widget) => widget.runtimeType.toString() == '_MorphHybridColumnFlight',
                  ),
                )
                .evaluate()
                .length,
            fallback.evaluate().length,
            interpolatedPadding.evaluate().length,
            interpolatedSize.evaluate().length,
          ),
          (0, 1, 1, 1),
        );
      },
    );

    testWidgets(
      'when a raw island uses a GlobalKey, it should remain on the guarded widget fallback',
      (tester) async {
        final sourceKey = GlobalKey();
        final destinationKey = GlobalKey();
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            builder: ({required destination}) => Column(
              children: [
                Builder(
                  key: destination ? destinationKey : sourceKey,
                  builder: (context) => const SizedBox.square(
                    dimension: 32,
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));

        expect(
          (
            find
                .descendant(
                  of: _columnMorphOverlay(),
                  matching: find.byWidgetPredicate(
                    (widget) => widget.runtimeType.toString() == '_MorphHybridColumnFlight',
                  ),
                )
                .evaluate()
                .length,
            find
                .descendant(
                  of: _columnMorphOverlay(),
                  matching: find.byWidgetPredicate(
                    (widget) => widget.runtimeType.toString() == '_MorphColumnFlight',
                  ),
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
      'when a hybrid flight is removed early, it should dispose its raw animation listener',
      (tester) async {
        var transitionBuilds = 0;
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            switchTransition: (child, animation) {
              transitionBuilds += 1;
              return FadeTransition(opacity: animation, child: child);
            },
            builder: ({required destination}) => Column(
              children: [
                Builder(
                  key: const ValueKey('disposed-hybrid-raw'),
                  builder: (context) => const SizedBox.square(
                    dimension: 32,
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final buildsBeforeRemoval = transitionBuilds;

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          (transitionBuilds, tester.takeException()),
          (buildsBeforeRemoval, null),
        );
      },
    );

    testWidgets(
      'when a nested Morph finishes inside a hybrid raw island, it should remain held until the parent arrives',
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
                    child: SizedBox(
                      width: 240,
                      height: 180,
                      child: Morph(
                        tag: 'hybrid-nested-parent',
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.linear,
                        child: Column(
                          children: [
                            Builder(
                              key: const ValueKey(
                                'hybrid-nested-raw-island',
                              ),
                              builder: (context) => Column(
                                children: [
                                  Morph(
                                    tag: 'hybrid-nested-child',
                                    duration: const Duration(
                                      milliseconds: 200,
                                    ),
                                    curve: Curves.linear,
                                    onEnd: destination ? null : () => childEvents.add('end'),
                                    onReceived: destination ? () => childEvents.add('received') : null,
                                    child: Text(
                                      destination ? 'Hybrid nested destination' : 'Hybrid nested source',
                                      key: ValueKey(
                                        'hybrid-nested-title-$destination',
                                      ),
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
        final hybridFlights = find
            .descendant(
              of: _columnMorphOverlay(),
              matching: find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_MorphHybridColumnFlight',
              ),
            )
            .evaluate()
            .length;
        final heldBoundaries = find
            .descendant(
              of: _columnMorphOverlay(),
              matching: find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_MorphFlightBoundary',
              ),
            )
            .evaluate()
            .length;
        final eventsWhileHeld = List<String>.of(childEvents);
        await tester.pumpAndSettle();

        expect(
          (
            hybridFlights,
            heldBoundaries,
            eventsWhileHeld.join(','),
            childEvents.join(','),
            find.text('Hybrid nested destination').evaluate().length,
            tester.takeException(),
          ),
          (1, 2, 'received,end', 'received,end', 1, null),
        );
      },
    );

    testWidgets(
      'when a hybrid raw island paints overflow, it should keep the existing Column flight clip',
      (tester) async {
        tester.view.physicalSize = const Size(220, 140);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('hybrid-raw-clip-boundary');
        const wrapperKey = ValueKey('hybrid-raw-clip-wrapper');
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
                    return Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: 120,
                        height: 100,
                        child: Morph(
                          tag: 'hybrid-raw-clip',
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.linear,
                          child: Column(
                            children: [
                              SizedBox(
                                key: wrapperKey,
                                width: 30,
                                height: 30,
                                child: OverflowBox(
                                  maxWidth: 70,
                                  maxHeight: 70,
                                  child: ColoredBox(
                                    color: destination ? Colors.blue : Colors.red,
                                    child: const SizedBox.square(
                                      dimension: 70,
                                    ),
                                  ),
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
          ),
        );
        await tester.pumpAndSettle();
        final restingRect = tester.getRect(find.byKey(wrapperKey));

        update(() => destination = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final flight = await _capturePixels(tester, boundaryKey);
        final inside = Rect.fromLTRB(
          restingRect.left,
          restingRect.top,
          restingRect.right,
          restingRect.bottom,
        );
        final overflow = Rect.fromLTRB(
          restingRect.right,
          restingRect.top,
          restingRect.right + 20,
          restingRect.bottom,
        );

        expect(
          (
            _redPixelCount(flight, inside) > 0,
            _redPixelCount(flight, overflow),
          ),
          (true, 0),
        );
      },
    );

    testWidgets(
      'when matched child types differ, it should switch them discretely without an assertion',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            builder: ({required destination}) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Stable'),
                if (destination)
                  Container(
                    key: const ValueKey('box-child'),
                    width: 60,
                    height: 40,
                    color: Colors.blue,
                  )
                else
                  const Text('Changing'),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 220));

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when the source is narrower, flight text should wrap inside the interpolated width',
      (tester) async {
        const title = 'Oficial Mecanico de Refrigeracao Veicular';
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            sourceWidth: 180,
            destinationWidth: 360,
            builder: ({required destination}) => Column(
              key: ValueKey(destination),
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 22),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        final rect = _columnFlightText(tester, title).rect;

        expect((rect.left >= -1, rect.right <= 200), (true, true));
      },
    );

    testWidgets(
      'when non-wrapping Column text is clipped, it should retain one line without painting outside its rect',
      (tester) async {
        tester.view.physicalSize = const Size(300, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const text = 'MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM';
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            sourceWidth: 100,
            destinationWidth: 120,
            builder: ({required destination}) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: const Color(0xFFFF00FF),
                    fontSize: destination ? 28 : 20,
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final entry = _columnFlightText(tester, text);
        final layout = _retainedTextLayouts(
          tester,
        ).singleWhere((layout) => layout['text'] == text);
        final clipRect = layout['clipRect']! as Rect;

        expect(
          (
            find
                .byWidgetPredicate(
                  (widget) => widget.runtimeType.toString() == '_MorphCompoundFlight',
                )
                .evaluate()
                .length,
            entry.paintedLineCount,
            clipRect.left,
            clipRect.right,
          ),
          (1, 1, entry.rect.left, entry.rect.right),
        );
      },
    );

    testWidgets(
      'when a matched paragraph outlives its shrinking Column bounds, it should not paint below the ancestor',
      (tester) async {
        tester.view.physicalSize = const Size(320, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey<String>('shrinking-column-boundary');
        const paragraph =
            'This complete description remains selected until late in the '
            'flight, but it must stop painting where its shrinking ancestor '
            'ends instead of continuing over the content behind it.';
        var compact = false;
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
                          width: 220,
                          child: Morph(
                            tag: 'shrinking-column',
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.linear,
                            switchThreshold: 0.97,
                            child: Column(
                              key: ValueKey(compact),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Title', key: ValueKey('shrinking-title')),
                                if (compact)
                                  const Padding(
                                    key: ValueKey('shrinking-description'),
                                    padding: EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Compact summary',
                                      style: TextStyle(color: Colors.red, fontSize: 18),
                                    ),
                                  )
                                else
                                  const Motion(
                                    effect: FadeInMotionEffect(),
                                    child: Text(
                                      paragraph,
                                      key: ValueKey('shrinking-description'),
                                      style: TextStyle(color: Colors.red, fontSize: 18),
                                    ),
                                  ),
                              ],
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
        final expandedHeight = tester.getSize(find.byType(Column).last).height;
        update(() => compact = true);
        await tester.pumpAndSettle();
        final compactHeight = tester.getSize(find.byType(Column).last).height;
        update(() => compact = false);
        await tester.pumpAndSettle();
        update(() => compact = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final frame = await _capturePixels(tester, boundaryKey);
        final animatedBottom = 20 + (expandedHeight + compactHeight) / 2;

        expect(
          _redPixelCount(
            frame,
            Rect.fromLTRB(15, animatedBottom + 1, 260, 480),
          ),
          0,
        );
      },
    );

    testWidgets(
      'when a Column Morph moves with a clipped ancestor Morph, it should not paint below the ancestor flight',
      (tester) async {
        tester.view.physicalSize = const Size(320, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey<String>('nested-column-boundary');
        const paragraph =
            'This complete description is intentionally much taller than its '
            'surface. While both shared elements move together, every line '
            'must remain clipped by the exact animated surface bounds. The '
            'descendant cannot continue painting over the content behind the '
            'surface merely because it owns an independent Morph flight.';
        var compact = false;
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
                            tag: 'clipping-ancestor',
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.linear,
                            child: Container(
                              key: ValueKey(('clipping-ancestor', compact)),
                              width: 240,
                              height: compact ? 110 : 220,
                              padding: const EdgeInsets.all(16),
                              clipBehavior: Clip.hardEdge,
                              decoration: const BoxDecoration(color: Colors.white),
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                minWidth: 208,
                                maxWidth: 208,
                                minHeight: 0,
                                maxHeight: double.infinity,
                                child: Morph(
                                  tag: 'nested-column',
                                  switchThreshold: 0.97,
                                  child: Column(
                                    key: ValueKey(('nested-column', compact)),
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('Title'),
                                      Text(
                                        compact ? 'Compact summary' : paragraph,
                                        key: const ValueKey('nested-description'),
                                        style: const TextStyle(color: Colors.red, fontSize: 18),
                                      ),
                                    ],
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
          ),
        );
        await tester.pumpAndSettle();
        update(() => compact = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final frame = await _capturePixels(tester, boundaryKey);
        const animatedAncestorBottom = 20 + (220 + 110) / 2;

        expect(
          _redPixelCount(
            frame,
            const Rect.fromLTRB(15, animatedAncestorBottom + 1, 270, 480),
          ),
          0,
        );
      },
    );

    testWidgets(
      'when a nested Morph follows an ancestor clip, it should retain the clip layer between frames',
      (tester) async {
        var compact = false;
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
                        left: 20,
                        top: 20,
                        child: Morph(
                          tag: 'retained-clip-ancestor',
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.linear,
                          child: Container(
                            key: ValueKey(('retained-clip-ancestor', compact)),
                            width: 240,
                            height: compact ? 110 : 220,
                            color: Colors.white,
                            child: Morph(
                              tag: 'retained-clip-descendant',
                              child: Text(
                                compact ? 'Compact' : 'Expanded description',
                                key: ValueKey(('retained-clip-text', compact)),
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
        update(() => compact = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        ClipRectLayer ancestorClipLayer() {
          final rootLayer = RendererBinding.instance.renderViews.single.debugLayer!;
          return rootLayer.depthFirstIterateChildren().whereType<ClipRectLayer>().singleWhere(
            (layer) => layer.clipRect?.width == 240,
          );
        }

        final firstLayer = ancestorClipLayer();
        await tester.pump(const Duration(milliseconds: 16));
        final secondLayer = ancestorClipLayer();

        expect(secondLayer, same(firstLayer));
      },
    );

    testWidgets(
      'when a Column child wraps with visible overflow, it should retain every native pixel below its bounds',
      (tester) async {
        tester.view.physicalSize = const Size(300, 180);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey<String>('visible-column-boundary');
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
                            tag: 'visible-column',
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.linear,
                            child: Column(
                              key: ValueKey<String>(
                                'visible-column-$destination',
                              ),
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                SizedBox(
                                  width: 110,
                                  height: 28,
                                  child: Text(
                                    text,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
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
          find
              .byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_MorphColumnFlight',
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

    testWidgets(
      'when Column text fades at overflow, it should use the native paragraph shader',
      (tester) async {
        const text = 'Fade overflow text that is much wider than the Column';
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            sourceWidth: 100,
            destinationWidth: 120,
            builder: ({required destination}) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(fontSize: destination ? 28 : 20),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final overlay = _columnMorphOverlay();
        final flightText = find.descendant(
          of: overlay,
          matching: find.text(text),
        );
        final paragraph = tester.renderObject<RenderParagraph>(flightText);

        expect(
          (
            find
                .descendant(
                  of: overlay,
                  matching: find.byWidgetPredicate(
                    (widget) => widget.runtimeType.toString() == '_MorphCompoundFlight',
                  ),
                )
                .evaluate()
                .length,
            find
                .descendant(
                  of: overlay,
                  matching: find.byWidgetPredicate(
                    (widget) => widget.runtimeType.toString() == '_MorphColumnFlight',
                  ),
                )
                .evaluate()
                .length,
            paragraph.debugHasOverflowShader,
          ),
          (0, 1, true),
        );
      },
    );

    testWidgets(
      'when growing text begins its flight, it should not be constrained to the interpolated endpoint height',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            sourceWidth: 300,
            destinationWidth: 500,
            builder: ({required destination}) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Growing title',
                  style: TextStyle(fontSize: destination ? 34 : 22),
                ),
              ],
            ),
          ),
        );
        final sourceHeight = tester.getSize(find.text('Growing title')).height;
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        final flightHeight = _columnFlightText(
          tester,
          'Growing title',
        ).rect.height;

        expect(flightHeight >= sourceHeight, isTrue);
      },
    );

    testWidgets(
      'when returning to a narrower endpoint, a title that fits should remain on one line',
      (tester) async {
        const title = 'Mecanico';
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            sourceWidth: 180,
            destinationWidth: 360,
            builder: ({required destination}) => Column(
              key: ValueKey(destination),
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [Text(title, style: TextStyle(fontSize: 20))],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        final entry = _columnFlightText(tester, title);
        expect(
          _paintedLineCount(entry),
          1,
          reason:
              'width=${entry.rect.width} '
              'font=${entry.widget.style?.fontSize} '
              'maxLines=${entry.widget.maxLines}',
        );
      },
    );

    testWidgets(
      'when returning from a full description, it should switch the paragraph boundary atomically',
      (tester) async {
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            switchThreshold: 0.8,
            builder: ({required destination}) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  destination ? _ColumnMorphTestApp.description : _ColumnMorphTestApp.summary,
                  maxLines: destination ? null : 3,
                  overflow: destination ? null : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, height: 1.38),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final early = _columnFlightText(
          tester,
          _ColumnMorphTestApp.description,
        );
        await tester.pump(const Duration(milliseconds: 180));
        final later = _columnFlightText(
          tester,
          _ColumnMorphTestApp.description,
        );
        await tester.pump(const Duration(milliseconds: 110));
        final afterTransfer = _columnFlightText(
          tester,
          _ColumnMorphTestApp.summary,
        );

        expect(
          (
            early.widget.maxLines,
            later.widget.maxLines,
            (later.rect.top - early.rect.top).abs() < 0.5,
            afterTransfer.widget.maxLines,
            afterTransfer.widget.overflow,
          ),
          (null, null, true, 3, TextOverflow.ellipsis),
        );
      },
    );

    testWidgets(
      'when destination children are lower, every child should move monotonically downward',
      (tester) async {
        await tester.pumpWidget(
          const _ColumnMorphTestApp(
            builder: _verticalColumn,
          ),
        );
        await tester.pumpAndSettle();
        final sourceTitle = tester.getTopLeft(find.text('Title')).dy;
        final sourcePayment = tester.getTopLeft(find.text('Payment')).dy;

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));
        final flightTitle = _columnFlightText(tester, 'Title').rect.top;
        final flightPayment = _columnFlightText(tester, 'Payment').rect.top;
        await tester.pumpAndSettle();
        final destinationTitle = tester.getTopLeft(find.text('Title')).dy;
        final destinationPayment = tester.getTopLeft(find.text('Payment')).dy;

        expect(
          (
            sourceTitle < flightTitle && flightTitle < destinationTitle,
            sourcePayment < flightPayment && flightPayment < destinationPayment,
          ),
          (true, true),
          reason:
              'source=($sourceTitle, $sourcePayment) '
              'flight=($flightTitle, $flightPayment) '
              'destination=($destinationTitle, $destinationPayment)',
        );
      },
    );

    testWidgets(
      'when a retained Column flies, it should interpolate its outer bounds without a positioned transition',
      (tester) async {
        await tester.pumpWidget(
          const _ColumnMorphTestApp(builder: _verticalColumn),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        final startBounds = _retainedPaintBounds(tester);
        await tester.pump(const Duration(milliseconds: 200));
        final flightBounds = _retainedPaintBounds(tester);
        final hasPositionedTransition = find
            .descendant(
              of: _columnMorphOverlay(),
              matching: find.byType(PositionedTransition),
            )
            .evaluate()
            .isNotEmpty;
        await tester.pump(const Duration(milliseconds: 160));
        final endBounds = _retainedPaintBounds(tester);

        expect(
          (
            flightBounds.height > startBounds.height,
            flightBounds.height < endBounds.height,
            hasPositionedTransition,
          ),
          (true, true, false),
        );
      },
    );

    testWidgets(
      'when another Morph starts, it should preserve the retained Column flight plan',
      (tester) async {
        var firstDestination = false;
        var secondDestination = false;
        late StateSetter update;
        const firstSource = Morph(
          tag: 'retained-column',
          duration: Duration(seconds: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Text('Departing title'), Text('Departing detail')],
          ),
        );
        const firstArrival = Morph(
          tag: 'retained-column',
          duration: Duration(seconds: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Text('Arriving title'), Text('Arriving detail')],
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Stack(
                  children: [
                    Align(
                      alignment: firstDestination ? Alignment.bottomRight : Alignment.topLeft,
                      child: firstDestination ? firstArrival : firstSource,
                    ),
                    Align(
                      alignment: secondDestination ? Alignment.centerRight : Alignment.centerLeft,
                      child: Morph(
                        tag: 'unrelated-text',
                        child: Text(
                          secondDestination ? 'Second arriving' : 'Second departing',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        update(() => firstDestination = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final retainedFlightBefore = tester.widget(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphCompoundFlight',
          ),
        );
        update(() => secondDestination = true);
        await tester.pump();
        final retainedFlightAfter = tester.widget(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphCompoundFlight',
          ),
        );

        expect(identical(retainedFlightBefore, retainedFlightAfter), isTrue);
      },
    );

    testWidgets(
      'when returning to higher child positions, every child should move monotonically upward',
      (tester) async {
        await tester.pumpWidget(
          const _ColumnMorphTestApp(builder: _verticalColumn),
        );
        await tester.pumpAndSettle();
        final sourceTitle = tester.getTopLeft(find.text('Title')).dy;
        final sourcePayment = tester.getTopLeft(find.text('Payment')).dy;
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pumpAndSettle();
        final destinationTitle = tester.getTopLeft(find.text('Title')).dy;
        final destinationPayment = tester.getTopLeft(find.text('Payment')).dy;

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));
        final flightTitle = _columnFlightText(tester, 'Title').rect.top;
        final flightPayment = _columnFlightText(tester, 'Payment').rect.top;

        expect(
          (
            sourceTitle < flightTitle && flightTitle < destinationTitle,
            sourcePayment < flightPayment && flightPayment < destinationPayment,
          ),
          (true, true),
          reason:
              'source=($sourceTitle, $sourcePayment) '
              'flight=($flightTitle, $flightPayment) '
              'destination=($destinationTitle, $destinationPayment)',
        );
      },
    );

    testWidgets(
      'when returning to a wider source, it should rewrap the title to fewer lines',
      (tester) async {
        const title = 'Cozinha Noturno';
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            sourceWidth: 400,
            destinationWidth: 180,
            builder: ({required destination}) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: destination ? null : 2,
                  overflow: destination ? null : TextOverflow.ellipsis,
                  style: TextStyle(fontSize: destination ? 34 : 22),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 360));

        expect(_paintedLineCount(_columnFlightText(tester, title)), 1);
      },
    );

    testWidgets(
      'when a title gains lines, it should keep the following payment below the title',
      (tester) async {
        const title = 'Atendente de Relacionamento (Voz e Chat)';
        const payment = r'R$1.766,99/mes';
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            builder: ({required destination}) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: destination ? null : 2,
                  overflow: destination ? null : TextOverflow.ellipsis,
                  style: TextStyle(fontSize: destination ? 34 : 22),
                ),
                Text(payment, style: TextStyle(fontSize: destination ? 30 : 25)),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));
        final titleEntry = _columnFlightText(tester, title);
        final paymentEntry = _columnFlightText(tester, payment);
        final titleBottom = titleEntry.rect.bottom;
        final paymentTop = paymentEntry.rect.top;

        expect(
          (_paintedLineCount(titleEntry) >= 2, paymentTop >= titleBottom - 0.5),
          (true, true),
        );
      },
    );

    testWidgets(
      'when endpoint line counts differ, it should not exceed their ceiling or inject ellipsis',
      (tester) async {
        const title = 'Auxiliar de Cozinha Noturno Agua Branca';
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            sourceWidth: 280,
            destinationWidth: 560,
            builder: ({required destination}) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: destination ? null : 2,
                  overflow: destination ? null : TextOverflow.ellipsis,
                  style: TextStyle(fontSize: destination ? 34 : 22),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();

        final samples = <({bool injectedEllipsis, int lines})>[];
        var elapsed = Duration.zero;
        for (final time in const [
          Duration(milliseconds: 160),
          Duration(milliseconds: 240),
          Duration(milliseconds: 320),
        ]) {
          await tester.pump(time - elapsed);
          elapsed = time;
          final entry = _columnFlightText(tester, title);
          samples.add((
            injectedEllipsis: entry.widget.maxLines != 2 && entry.widget.overflow == TextOverflow.ellipsis,
            lines: _paintedLineCount(entry),
          ));
        }

        expect(
          (
            samples.every((sample) => sample.lines <= 3),
            samples.every((sample) => !sample.injectedEllipsis),
          ),
          (true, true),
        );
      },
    );

    testWidgets(
      'when text exceeds the flight width in either direction, it should wrap without ellipsis',
      (tester) async {
        const title = 'Atendente Geral de Restaurante';
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            builder: ({required destination}) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: destination ? null : 2,
                  overflow: destination ? null : TextOverflow.ellipsis,
                  style: TextStyle(fontSize: destination ? 34 : 22),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));
        final forward = _columnFlightText(tester, title);
        final forwardResult = (
          _paintedLineCount(forward) >= 2,
          forward.widget.overflow != TextOverflow.ellipsis,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final reverse = _columnFlightText(tester, title);

        expect(
          (
            forwardResult,
            (
              _paintedLineCount(reverse) >= 2,
              reverse.widget.overflow != TextOverflow.ellipsis,
            ),
          ),
          ((true, true), (true, true)),
          reason:
              'forward=(lines: ${_paintedLineCount(forward)}, '
              'maxLines: ${forward.widget.maxLines}, '
              'overflow: ${forward.widget.overflow}, '
              'font: ${forward.widget.style?.fontSize}) '
              'reverse=(lines: ${_paintedLineCount(reverse)}, '
              'maxLines: ${reverse.widget.maxLines}, '
              'overflow: ${reverse.widget.overflow}, '
              'font: ${reverse.widget.style?.fontSize})',
        );
      },
    );

    testWidgets(
      'when a reverse flight nears completion, its title height should match the settled source',
      (tester) async {
        const title = 'Cozinha Noturno';
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            sourceWidth: 400,
            destinationWidth: 180,
            builder: ({required destination}) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: destination ? 34 : 22)),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 399));
        final flightHeight = _columnFlightText(tester, title).rect.height;
        await tester.pumpAndSettle();
        final settledHeight = tester.getSize(find.text(title)).height;

        expect(
          (flightHeight - settledHeight).abs() < 2,
          isTrue,
          reason: 'flightHeight=$flightHeight settledHeight=$settledHeight',
        );
      },
    );

    testWidgets(
      'when font size interpolates in reverse, its baseline should move smoothly toward the source',
      (tester) async {
        const title = 'Auxiliar de Cozinha';
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            builder: ({required destination}) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: destination ? 34 : 22)),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();

        final baselines = <double>[];
        for (var index = 0; index < 8; index += 1) {
          await tester.pump(const Duration(milliseconds: 40));
          final entry = _columnFlightText(tester, title);
          baselines.add(entry.baseline);
        }
        final deltas = [
          for (var index = 1; index < baselines.length; index += 1) baselines[index] - baselines[index - 1],
        ];

        expect(deltas.every((delta) => delta < 0), isTrue);
      },
    );

    testWidgets(
      'when returning, the payment top should move monotonically upward without jumping',
      (tester) async {
        const title = 'Atendente de Relacionamento (Voz e Chat)';
        const payment = r'R$1.766,99/mes';
        await tester.pumpWidget(
          _ColumnMorphTestApp(
            builder: ({required destination}) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: destination ? null : 2,
                  overflow: destination ? null : TextOverflow.ellipsis,
                  style: TextStyle(fontSize: destination ? 34 : 22),
                ),
                Text(payment, style: TextStyle(fontSize: destination ? 30 : 25)),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(_ColumnMorphTestApp.toggleKey));
        await tester.pump();
        await tester.pump();

        final tops = <double>[];
        for (var index = 0; index < 4; index += 1) {
          await tester.pump(const Duration(milliseconds: 80));
          tops.add(
            _columnFlightText(tester, payment).rect.top,
          );
        }

        expect(
          [
            for (var index = 1; index < tops.length; index += 1) tops[index] < tops[index - 1],
          ].every((movesUp) => movesUp),
          isTrue,
        );
      },
    );
  });
}

Column _verticalColumn({required bool destination}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(height: destination ? 60 : 10),
      const Text('Title'),
      SizedBox(height: destination ? 30 : 5),
      const Text('Payment'),
    ],
  );
}

class _ColumnMorphTestApp extends StatefulWidget {
  const _ColumnMorphTestApp({
    required this.builder,
    this.sourceWidth = 300,
    this.destinationWidth = 300,
    this.switchThreshold = 0.5,
    this.switchTransition,
    this.curve = Curves.linear,
  });

  static const ValueKey<String> toggleKey = ValueKey('toggle-column');
  static const summary = 'Empresa esta contratando Instrumentista para atuar no Jaragua.';
  static const description =
      'Empresa esta contratando Instrumentista para atuar no Jaragua, em Sao '
      'Paulo. A jornada ocorre de segunda a sexta, com intervalo e varias '
      'responsabilidades tecnicas descritas para o primeiro dia de trabalho.';

  final Column Function({required bool destination}) builder;
  final double sourceWidth;
  final double destinationWidth;
  final double switchThreshold;
  final AnimatedSwitcherTransitionBuilder? switchTransition;
  final Curve curve;

  @override
  State<_ColumnMorphTestApp> createState() => _ColumnMorphTestAppState();
}

class _ColumnMorphTestAppState extends State<_ColumnMorphTestApp> {
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
                width: _destination ? widget.destinationWidth : widget.sourceWidth,
                child: Morph(
                  tag: 'column-regression',
                  duration: const Duration(milliseconds: 400),
                  curve: widget.curve,
                  switchThreshold: widget.switchThreshold,
                  switchTransition: widget.switchTransition,
                  child: widget.builder(destination: _destination),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FilledButton(
                key: _ColumnMorphTestApp.toggleKey,
                onPressed: () => setState(() => _destination = !_destination),
                child: const Text('Toggle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ExtremeHybridOvershootCurve extends Curve {
  const _ExtremeHybridOvershootCurve();

  @override
  double transformInternal(double t) {
    return t < 0.25 ? -2 : 2;
  }
}

final class _CountingKey extends LocalKey {
  const _CountingKey(this.value);

  static int comparisons = 0;

  final int value;

  @override
  int get hashCode => value.hashCode;

  @override
  bool operator ==(Object other) {
    comparisons += 1;
    return other is _CountingKey && value == other.value;
  }
}
