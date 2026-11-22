part of '../motion.dart';

/// Filters a single nearly sharp glyph with one bounded atlas draw.
class _MotionSparseTextBlur {
  static const double maximumSigmaInPixels = 1.05;

  final Float32List _transforms = Float32List(36);
  final Float32List _rects = Float32List(36);
  final Int32List _weights = Int32List(9);
  final Paint _tapPaint = Paint()
    ..blendMode = BlendMode.plus
    ..filterQuality = FilterQuality.low;
  final Paint _resultPaint = Paint();

  bool paint(
    Canvas canvas,
    ui.Image atlas,
    Float32List transforms,
    Float32List rects,
    Int32List? colors,
    Paint sharpPaint, {
    required int glyph,
    required double sigmaInPixels,
    required double devicePixelRatio,
  }) {
    final variance = sigmaInPixels * sigmaInPixels;
    // Pair each side's first two Gaussian taps into one bilinear sample.
    final first = math.exp(-.5 / variance);
    final second = math.exp(-2 / variance);
    final side = first + second;
    if (side == 0) return false;
    final span = (1 + second / side) / devicePixelRatio;
    final centerWeight = 1 / (1 + 2 * side);
    final sideWeight = side * centerWeight;
    final crossWeight = (255 * sideWeight * centerWeight).round();
    final cornerWeight = (255 * sideWeight * sideWeight).round();
    if (crossWeight == 0 && cornerWeight == 0) {
      _MotionBlur.drawAtlasRange(canvas, atlas, transforms, rects, colors, sharpPaint, start: glyph, end: glyph + 1);
      return true;
    }
    final base = glyph * 4;
    final a = transforms[base];
    final b = transforms[base + 1];
    final x = transforms[base + 2];
    final y = transforms[base + 3];
    final width = rects[base + 2] - rects[base];
    final height = rects[base + 3] - rects[base + 1];
    final across = a * width;
    final down = b * height;
    final right = b * width;
    final bottom = a * height;
    final bounds = Rect.fromLTRB(
      x + math.min(0, across) - math.max(0, down) - span,
      y + math.min(0, right) + math.min(0, bottom) - span,
      x + math.max(0, across) - math.min(0, down) + span,
      y + math.max(0, right) + math.max(0, bottom) + span,
    );
    final alpha = colors == null ? 255 : (colors[glyph] >> 24) & 255;
    var count = 0;
    for (var row = -1; row <= 1; row++) {
      for (var column = -1; column <= 1; column++) {
        final weight = row != 0 && column != 0
            ? cornerWeight
            : row != 0 || column != 0
            ? crossWeight
            : 255 - 4 * (cornerWeight + crossWeight);
        if (weight == 0) continue;
        final tap = count * 4;
        _transforms[tap] = a;
        _transforms[tap + 1] = b;
        _transforms[tap + 2] = x + column * span;
        _transforms[tap + 3] = y + row * span;
        _rects.setRange(tap, tap + 4, rects, base);
        _weights[count++] = weight << 24;
      }
    }
    _resultPaint.color = Color.fromARGB(alpha, 255, 255, 255);
    canvas.saveLayer(bounds, _resultPaint);
    _MotionBlur.drawAtlasRange(
      canvas,
      atlas,
      _transforms,
      _rects,
      _weights,
      _tapPaint,
      start: 0,
      end: count,
    );
    canvas.restore();
    return true;
  }
}
