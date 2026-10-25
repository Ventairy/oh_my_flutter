import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Renders backdrops against transparency for observable pixel assertions.
class ContourTestHarness {
  /// The boundary around the complete test composition.
  final GlobalKey boundaryKey = GlobalKey();

  /// The backing widget's key.
  final GlobalKey backdropKey = GlobalKey();

  /// Mounts [child] in a consistently sized transparent canvas.
  Future<void> mount(
    WidgetTester tester, {
    required Widget child,
    Color color = const Color(0xFFFFFFFF),
    double amount = 0,
    List<Shadow> shadows = const [],
    double pixelRatio = 1,
    Offset translation = Offset.zero,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(devicePixelRatio: pixelRatio),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox.square(
                dimension: 100,
                child: Center(
                  child: Transform.scale(
                    scale: scale,
                    child: Transform.translate(
                      offset: translation,
                      child: Contour(
                        key: backdropKey,
                        color: color,
                        amount: amount,
                        shadows: shadows,

                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// Waits for asynchronous rendering without freezing the real engine clock.
  static Future<void> settle(WidgetTester tester) async {
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 1));
      final generating = tester
          .renderObjectList<RenderObject>(find.byType(Contour))
          .any(
            (render) => render.toDiagnosticsNode().getProperties().any(
              (property) => property.name == 'generating' && property.value == true,
            ),
          );
      if (!generating && !tester.binding.hasScheduledFrame) return;
    }
    throw StateError('Contour did not finish generating.');
  }

  /// Counts source captures to detect redundant work during external movement.
  int get captureCount =>
      backdropKey.currentContext!
              .findRenderObject()!
              .toDiagnosticsNode()
              .getProperties()
              .firstWhere((p) => p.name == 'captureCount')
              .value!
          as int;

  /// Captures the composition's premultiplied RGBA pixels.
  Future<Uint8List> pixels(WidgetTester tester, {double pixelRatio = 1}) async {
    final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: pixelRatio));
    try {
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
      return bytes!.buffer.asUint8List();
    } finally {
      image!.dispose();
    }
  }

  /// Counts mismatched pixels farther than half a logical pixel from the native edge.
  ///
  /// Both inputs are captures of the fixed canvas at four pixels per logical pixel.
  static int countDistantEdges(Uint8List actual, Uint8List reference) {
    final edges = _edgeSegments(reference);
    var mismatches = 0;
    for (var y = 0; y < 400; y++) {
      for (var x = 0; x < 400; x++) {
        final index = (y * 400 + x) * 4 + 3;
        if ((actual[index] >= 128) == (reference[index] >= 128)) continue;
        var nearby = false;
        for (final (start, end) in edges) {
          final dx = end.dx - start.dx;
          final dy = end.dy - start.dy;
          final length = dx * dx + dy * dy;
          final fraction = length == 0
              ? 0.0
              : (((x + .5 - start.dx) * dx + (y + .5 - start.dy) * dy) / length).clamp(0.0, 1.0);
          final distanceX = x + .5 - start.dx - dx * fraction;
          final distanceY = y + .5 - start.dy - dy * fraction;
          if (distanceX * distanceX + distanceY * distanceY <= 4) {
            nearby = true;
            break;
          }
        }
        if (!nearby) mismatches++;
      }
    }
    return mismatches;
  }

  static List<(Offset, Offset)> _edgeSegments(Uint8List pixels) {
    final segments = <(Offset, Offset)>[];
    for (var y = 0; y < 399; y++) {
      for (var x = 0; x < 399; x++) {
        final alpha = [
          pixels[(y * 400 + x) * 4 + 3],
          pixels[(y * 400 + x + 1) * 4 + 3],
          pixels[((y + 1) * 400 + x + 1) * 4 + 3],
          pixels[((y + 1) * 400 + x) * 4 + 3],
        ];
        if (alpha.every((value) => value < 128) || alpha.every((value) => value >= 128)) continue;
        final corners = [
          Offset(x + .5, y + .5),
          Offset(x + 1.5, y + .5),
          Offset(x + 1.5, y + 1.5),
          Offset(x + .5, y + 1.5),
        ];
        final crossings = <Offset>[];
        for (var edge = 0; edge < 4; edge++) {
          final next = (edge + 1) % 4;
          if ((alpha[edge] < 127.5) == (alpha[next] < 127.5)) continue;
          crossings.add(
            Offset.lerp(corners[edge], corners[next], (127.5 - alpha[edge]) / (alpha[next] - alpha[edge]))!,
          );
        }
        for (var edge = 0; edge + 1 < crossings.length; edge += 2) {
          segments.add((crossings[edge], crossings[edge + 1]));
        }
      }
    }
    return segments;
  }

  /// Returns an RGBA pixel in the fixed 100-pixel canvas.
  static List<int> pixel(Uint8List bytes, int x, int y) => bytes.sublist((y * 100 + x) * 4, (y * 100 + x) * 4 + 4);
}
