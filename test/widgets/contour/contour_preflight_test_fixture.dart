import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'contour_repaint_test_painter.dart';
import 'contour_test_harness.dart';

/// Exercises source observation through nested paint and export boundaries.
class ContourPreflightTestFixture extends ContourTestHarness {
  /// Creates a paint-only source, optionally wrapped in a second contour.
  new({this.nested = false});

  /// Whether another contour wraps the source's own contour.
  final bool nested;

  /// The smaller export boundary around the contoured source.
  final GlobalKey innerBoundaryKey = GlobalKey();

  /// Requests a paint-only change to the source's color and visible width.
  final ValueNotifier<bool> changed = ValueNotifier(false);

  /// Mounts the source between 100-pixel and 80-pixel export boundaries.
  Widget get widget => Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(
      key: boundaryKey,
      child: Center(
        child: RepaintBoundary(
          key: innerBoundaryKey,
          child: SizedBox.square(
            dimension: 80,
            child: Center(
              child: nested
                  ? Contour(amount: 4, color: const Color(0xffffffff), child: _contouredSource)
                  : _contouredSource,
            ),
          ),
        ),
      ),
    ),
  );

  Widget get _contouredSource => Contour(
    key: backdropKey,
    amount: 4,
    color: const Color(0xffffffff),
    child: RepaintBoundary(
      child: CustomPaint(
        size: const Size.square(40),
        painter: ContourRepaintTestPainter(changed),
      ),
    ),
  );

  /// Reads a source diagnostic without importing private implementation types.
  Object? diagnostic(String name) => backdropKey.currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .singleWhere((property) => property.name == name)
      .value;

  /// Forces decoration composition while preserving retained source layers.
  void recomposeDecorations() {
    for (final element in find.byType(Contour).evaluate()) {
      element.renderObject!.debugLayer!.firstChild!.markNeedsAddToScene();
    }
  }

  /// Composes a new export scene for the selected public repaint boundary.
  Future<ui.Image> capture({required GlobalKey key}) =>
      (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();

  /// Reads an exported image's premultiplied RGBA pixels.
  Future<Uint8List> imagePixels(WidgetTester tester, ui.Image image) async {
    final bytes = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
    return bytes!.buffer.asUint8List();
  }

  /// Returns one RGBA pixel from an export of arbitrary [width].
  static (int, int, int, int) imagePixel(Uint8List bytes, {required int width, required int x, required int y}) {
    final offset = (y * width + x) * 4;
    return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3]);
  }

  /// Releases the notifier used by the source's repaint listener.
  void dispose() => changed.dispose();
}
