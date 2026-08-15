import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Future<Color> _centerPixel(WidgetTester tester, Finder boundaryFinder) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final offset = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
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

void main() {
  group('Morph DecoratedBox', () {
    test('when no curve is provided, it should defer curve resolution', () {
      const morph = Morph(
        tag: 'default-curve',
        child: DecoratedBox(decoration: BoxDecoration()),
      );

      expect(morph.curve, isNull);
    });

    testWidgets('when building at rest, it should preserve the original decorated box', (tester) async {
      const decoration = BoxDecoration(color: Colors.red);
      await tester.pumpWidget(
        const MaterialApp(
          home: Morph(
            tag: 'decorated-box',
            child: DecoratedBox(
              key: ValueKey('decorated-box'),
              position: DecorationPosition.foreground,
              decoration: decoration,
              child: SizedBox.square(dimension: 80),
            ),
          ),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(find.byKey(const ValueKey('decorated-box')));
      expect((decoratedBox.decoration, decoratedBox.position), (decoration, DecorationPosition.foreground));
    });

    testWidgets('when a foreground decorated box flies, it should keep its decoration above its child', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      const boundaryKey = ValueKey('decorated-box-boundary');
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
                    alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                    child: SizedBox.square(
                      dimension: destination ? 140 : 80,
                      child: Morph(
                        tag: 'foreground-decorated-box',
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.linear,
                        child: DecoratedBox(
                          key: ValueKey(destination),
                          position: DecorationPosition.foreground,
                          decoration: const BoxDecoration(color: Colors.red),
                          child: const ColoredBox(color: Colors.green),
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
      await tester.pump(const Duration(milliseconds: 150));
      final pixel = await _centerPixel(tester, find.byKey(boundaryKey));
      final hybridFlightCount = find
          .byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MorphHybridContainerFlight',
          )
          .evaluate()
          .length;
      await tester.pumpAndSettle();

      expect(
        (pixel.toARGB32(), hybridFlightCount),
        (Colors.red.toARGB32(), 1),
      );
    });
  });
}
