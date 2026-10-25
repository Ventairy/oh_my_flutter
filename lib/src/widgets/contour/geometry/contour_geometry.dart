part of 'contour_geometry_cache.dart';

/// Shares an accepted source fill and its visible paint bounds.
class ContourGeometry {
  /// Copies a painter's final filled shape.
  new declared(ui.Path source) : _hash = 0 {
    shape = ui.Path.from(source);
    bounds = shape.getBounds();
    // Unknown complexity: declared geometry bypasses optional retained caches.
    estimatedBytes = 0;
  }

  new _(
    this._hash,
    List<Float64List> curves, {
    required double pixelRatio,
    required ui.Offset origin,
  }) {
    final result = ui.Path()..fillType = ui.PathFillType.evenOdd;
    var bytes = 256;
    for (final curve in curves) {
      result.moveTo(origin.dx + curve[0] / pixelRatio, origin.dy + curve[1] / pixelRatio);
      for (var i = 2; i < curve.length; i += 6) {
        result.cubicTo(
          origin.dx + curve[i] / pixelRatio,
          origin.dy + curve[i + 1] / pixelRatio,
          origin.dx + curve[i + 2] / pixelRatio,
          origin.dy + curve[i + 3] / pixelRatio,
          origin.dx + curve[i + 4] / pixelRatio,
          origin.dy + curve[i + 5] / pixelRatio,
        );
      }
      result.close();
      // Native curve storage is not exposed by Path. Keep the existing
      // two-times coordinate allowance rather than charging its Dart input.
      bytes += curve.lengthInBytes * 2 + 32;
    }
    shape = result;
    bounds = result.getBounds();
    estimatedBytes = bytes;
  }

  final int _hash;

  /// The source fill; consumers of this internal type must not mutate it.
  late final ui.Path shape;

  /// The visible source bounds before adding an amount or shadows.
  late final ui.Rect bounds;

  /// Conservative storage for the source fill and its value metadata.
  late final int estimatedBytes;
}
