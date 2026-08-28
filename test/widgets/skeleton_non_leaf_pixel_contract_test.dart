import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

const _boneColor = Color(0xFF536579);

MaterialApp _pixelApp({required Key boundaryKey, required Widget child}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: RepaintBoundary(key: boundaryKey, child: child),
      ),
    ),
  );
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

Color _pixelAt(
  ({int height, List<int> pixels, int width}) frame,
  int x,
  int y,
) {
  final offset = (y * frame.width + x) * 4;
  return Color.fromARGB(
    frame.pixels[offset + 3],
    frame.pixels[offset],
    frame.pixels[offset + 1],
    frame.pixels[offset + 2],
  );
}

bool _containsSaturatedSourcePixel(
  ({int height, List<int> pixels, int width}) frame,
) {
  for (var offset = 0; offset < frame.pixels.length; offset += 4) {
    final red = frame.pixels[offset];
    final green = frame.pixels[offset + 1];
    final blue = frame.pixels[offset + 2];
    final alpha = frame.pixels[offset + 3];
    if (alpha == 0) continue;

    final redSource = red > 160 && red > green + 80 && red > blue + 80;
    final greenSource = green > 140 && green > red + 70 && green > blue + 70;
    final blueSource = blue > 160 && blue > red + 80 && blue > green + 60;
    if (redSource || greenSource || blueSource) return true;
  }
  return false;
}

bool _containsBonePixel(
  ({int height, List<int> pixels, int width}) frame,
) {
  for (var offset = 0; offset < frame.pixels.length; offset += 4) {
    final color = Color.fromARGB(
      frame.pixels[offset + 3],
      frame.pixels[offset],
      frame.pixels[offset + 1],
      frame.pixels[offset + 2],
    );
    if (color == _boneColor) return true;
  }
  return false;
}

Skeleton _skeleton(Widget child) {
  return Skeleton(
    style: const SkeletonStyle(color: _boneColor, radius: Radius.zero),
    child: SizedBox(width: 64, height: 40, child: child),
  );
}

Widget _centerSourceLeaf() {
  return const Center(
    child: SizedBox(
      width: 20,
      height: 12,
      child: ColoredBox(color: Colors.blue),
    ),
  );
}

void main() {
  // The first render object that paints on each branch becomes the bone and
  // terminates traversal below it.
  group('Skeleton non-leaf pixel contract', () {
    testWidgets(
      'when a decorated box paints behind a child, it should replace the surface and omit the child',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-decorated-box-pixels');
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: _skeleton(
              DecoratedBox(
                decoration: const BoxDecoration(color: Colors.red),
                child: _centerSourceLeaf(),
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(
          (
            background: _pixelAt(frame, 4, 20).toARGB32(),
            child: _pixelAt(frame, 32, 20).toARGB32(),
            sourceColorVisible: _containsSaturatedSourcePixel(frame),
          ),
          (
            background: _boneColor.toARGB32(),
            child: _boneColor.toARGB32(),
            sourceColorVisible: false,
          ),
        );
      },
    );

    testWidgets(
      'when a colored container paints behind a child, it should replace the surface and omit the child',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-container-pixels');
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: _skeleton(
              Container(
                color: Colors.green,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 20,
                  height: 12,
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(
          (
            background: _pixelAt(frame, 4, 20).toARGB32(),
            child: _pixelAt(frame, 32, 20).toARGB32(),
            sourceColorVisible: _containsSaturatedSourcePixel(frame),
          ),
          (
            background: _boneColor.toARGB32(),
            child: _boneColor.toARGB32(),
            sourceColorVisible: false,
          ),
        );
      },
    );

    testWidgets(
      'when a physical model paints behind a child, it should replace the surface and omit the child',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-physical-model-pixels');
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: _skeleton(
              PhysicalModel(
                color: Colors.red,
                elevation: 0,
                child: _centerSourceLeaf(),
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(
          (
            background: _pixelAt(frame, 4, 20).toARGB32(),
            child: _pixelAt(frame, 32, 20).toARGB32(),
            sourceColorVisible: _containsSaturatedSourcePixel(frame),
          ),
          (
            background: _boneColor.toARGB32(),
            child: _boneColor.toARGB32(),
            sourceColorVisible: false,
          ),
        );
      },
    );

    testWidgets(
      'when a card paints behind a child, it should replace the surface and omit the child',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-card-pixels');
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: _skeleton(
              Card(
                color: Colors.green,
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(),
                child: _centerSourceLeaf(),
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(
          (
            background: _pixelAt(frame, 4, 20).toARGB32(),
            child: _pixelAt(frame, 32, 20).toARGB32(),
            sourceColorVisible: _containsSaturatedSourcePixel(frame),
          ),
          (
            background: _boneColor.toARGB32(),
            child: _boneColor.toARGB32(),
            sourceColorVisible: false,
          ),
        );
      },
    );

    testWidgets(
      'when custom painters surround a child, it should replace their paint and omit the child source',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-custom-paint-pixels');
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: _skeleton(
              CustomPaint(
                painter: const _SaturatedPainter(color: Colors.red),
                foregroundPainter: const _SaturatedPainter(
                  color: Colors.green,
                  topBandOnly: true,
                ),
                child: _centerSourceLeaf(),
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(
          (
            foreground: _pixelAt(frame, 4, 4).toARGB32(),
            background: _pixelAt(frame, 4, 20).toARGB32(),
            child: _pixelAt(frame, 32, 20).toARGB32(),
            sourceColorVisible: _containsSaturatedSourcePixel(frame),
          ),
          (
            foreground: _boneColor.toARGB32(),
            background: _boneColor.toARGB32(),
            child: _boneColor.toARGB32(),
            sourceColorVisible: false,
          ),
        );
      },
    );

    testWidgets(
      'when a non-leaf custom painter draws text, it should capture the text and omit the child',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-custom-paint-text-pixels');
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: _skeleton(
              CustomPaint(
                painter: const _SaturatedPainter(
                  color: Colors.red,
                  drawText: true,
                ),
                child: _centerSourceLeaf(),
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(
          (
            hasBone: _containsBonePixel(frame),
            childAlpha: _pixelAt(frame, 32, 20).a,
            sourceColorVisible: _containsSaturatedSourcePixel(frame),
          ),
          (hasBone: true, childAlpha: 0.0, sourceColorVisible: false),
        );
      },
    );
  });
}

class _SaturatedPainter extends CustomPainter {
  const _SaturatedPainter({
    required this.color,
    this.drawText = false,
    this.topBandOnly = false,
  });

  final Color color;
  final bool drawText;
  final bool topBandOnly;

  @override
  void paint(Canvas canvas, Size size) {
    if (drawText) {
      TextPainter(
          text: TextSpan(
            text: 'M',
            style: TextStyle(color: color, fontSize: 20),
          ),
          textDirection: TextDirection.ltr,
        )
        ..layout(maxWidth: size.width)
        ..paint(canvas, const Offset(2, 2))
        ..dispose();
      return;
    }

    final bounds = topBandOnly ? Rect.fromLTWH(0, 0, size.width, 8) : Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SaturatedPainter oldDelegate) => false;
}
