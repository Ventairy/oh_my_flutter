part of '../motion.dart';

/// Finds a compact atlas layout while retaining the original glyph order.
class _MotionPackedTextShelf {
  new(int glyphCount) : _widths = Int32List(glyphCount), _heights = Int32List(glyphCount);

  static const _limits = [256, 320, 384, 448, 512, 640, 768, 896];

  final Int32List _widths;
  final Int32List _heights;
  int _count = 0;

  void reset() => _count = 0;

  void add(int width, int height) {
    _widths[_count] = width;
    _heights[_count++] = height;
  }

  int? fitWidth() {
    var bestArea = _MotionPackedTextBlur._maximumPixels;
    int? bestLimit;
    for (final limit in _limits) {
      var left = 0;
      var top = 0;
      var rowHeight = 0;
      var width = 0;
      var fits = true;
      for (var index = 0; index < _count; index++) {
        final tileWidth = _widths[index];
        if (tileWidth > limit) {
          fits = false;
          break;
        }
        if (left + tileWidth > limit) {
          top += rowHeight;
          left = 0;
          rowHeight = 0;
        }
        left += tileWidth;
        width = math.max(width, left);
        rowHeight = math.max(rowHeight, _heights[index]);
        final height = top + rowHeight;
        if (height > _MotionPackedTextBlur._maximumDimension || width * height > bestArea) {
          fits = false;
          break;
        }
      }
      if (!fits) continue;
      bestArea = width * (top + rowHeight);
      bestLimit = limit;
    }
    return bestLimit;
  }
}
