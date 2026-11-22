part of '../motion.dart';

/// Resizes the selected fine tiles to reuse the earlier separable blur.
class _MotionPackedFineFamily {
  new(int glyphCount)
    : _scales = Float64List(glyphCount),
      _widths = Int32List(glyphCount),
      _heights = Int32List(glyphCount);

  // Skia uses the same separable program for sigma 1.01 as for the earlier
  // passes. Use the smaller kernel to limit the size of the resized tiles.
  static const double sigma = 1.01;
  static const List<int> _shelfWidths = [
    256,
    320,
    384,
    448,
    512,
    640,
    768,
    896,
    _MotionPackedTextBlur._maximumDimension,
  ];

  final Float64List _scales;
  final Int32List _widths;
  final Int32List _heights;

  ({int width, int height})? resize(
    _MotionPackedTextBlur pack,
    Float64List sigmas,
    Float32List transforms, {
    required int count,
  }) {
    final padding = _MotionBlur.outset(sigma).toInt() + 2;
    final slotByGlyph = pack._slotByGlyph;
    final inputRects = pack._inputRects;
    for (var glyph = 0; glyph < slotByGlyph.length; glyph++) {
      final slot = slotByGlyph[glyph];
      if (slot < 0) continue;
      final source = glyph * 4;
      final destination = slot * 4;
      final rasterScale = _MotionPackedTextBlur._sourceScale(transforms[source], transforms[source + 1]);
      final scale = sigma * rasterScale / sigmas[glyph];
      _scales[slot] = scale;
      _widths[slot] = ((inputRects[destination + 2] - inputRects[destination]) * scale).ceil() + padding * 2;
      _heights[slot] = ((inputRects[destination + 3] - inputRects[destination + 1]) * scale).ceil() + padding * 2;
    }

    var budget = _MotionPackedTextBlur._maximumPixels;
    var shelfWidth = 0;
    ({int width, int height})? best;
    for (final limit in _shelfWidths) {
      final size = _measure(count, limit);
      if (size == null || size.width * size.height > budget) continue;
      best = size;
      budget = size.width * size.height;
      shelfWidth = limit;
    }
    // Keep the original packing when the resized tiles exceed the budget.
    if (best == null) return null;

    final inputTransforms = pack._inputTransforms;
    final outputTransforms = pack._outputTransforms;
    final outputRects = pack._outputRects;
    var left = 0;
    var top = 0;
    var rowHeight = 0;
    for (var glyph = 0; glyph < slotByGlyph.length; glyph++) {
      final slot = slotByGlyph[glyph];
      if (slot < 0) continue;
      final tileWidth = _widths[slot];
      final tileHeight = _heights[slot];
      if (left + tileWidth > shelfWidth) {
        top += rowHeight;
        left = 0;
        rowHeight = 0;
      }
      final source = glyph * 4;
      final destination = slot * 4;
      final scale = _scales[slot];
      final outputA = transforms[source] / scale;
      final outputB = transforms[source + 1] / scale;

      inputTransforms[destination] = scale;
      inputTransforms[destination + 2] = (left + padding).toDouble();
      inputTransforms[destination + 3] = (top + padding).toDouble();
      outputRects[destination] = left.toDouble();
      outputRects[destination + 1] = top.toDouble();
      outputRects[destination + 2] = (left + tileWidth).toDouble();
      outputRects[destination + 3] = (top + tileHeight).toDouble();
      outputTransforms[destination] = outputA;
      outputTransforms[destination + 1] = outputB;
      outputTransforms[destination + 2] = transforms[source + 2] + padding * (outputB - outputA);
      outputTransforms[destination + 3] = transforms[source + 3] - padding * (outputB + outputA);
      left += tileWidth;
      rowHeight = math.max(rowHeight, tileHeight);
    }
    return best;
  }

  ({int width, int height})? _measure(int count, int limit) {
    var maxWidth = 0;
    var left = 0;
    var top = 0;
    var rowHeight = 0;
    for (var slot = 0; slot < count; slot++) {
      final tileWidth = _widths[slot];
      final tileHeight = _heights[slot];
      if (tileWidth > limit) return null;
      if (left + tileWidth > limit) {
        top += rowHeight;
        left = 0;
        rowHeight = 0;
      }
      rowHeight = math.max(rowHeight, tileHeight);
      if (top + rowHeight > _MotionPackedTextBlur._maximumDimension) return null;
      left += tileWidth;
      maxWidth = math.max(maxWidth, left);
    }
    return (width: maxWidth, height: top + rowHeight);
  }
}
