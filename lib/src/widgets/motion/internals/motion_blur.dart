part of '../motion.dart';

class _MotionBlur {
  double _sigma = 0;
  ui.ImageFilter? _filter;
  late final _paint = Paint();

  void save(Canvas canvas, Rect bounds, double sigma) {
    _paint.imageFilter = filter(sigma);
    canvas.saveLayer(bounds.inflate(outset(sigma)), _paint);
  }

  static void drawAtlasRange(
    Canvas canvas,
    ui.Image image,
    Float32List transforms,
    Float32List rects,
    Int32List? colors,
    Paint paint, {
    required int start,
    required int end,
  }) {
    canvas.drawRawAtlas(
      image,
      Float32List.sublistView(transforms, start * 4, end * 4),
      Float32List.sublistView(rects, start * 4, end * 4),
      colors == null ? null : Int32List.sublistView(colors, start, end),
      colors == null ? null : BlendMode.srcIn,
      null,
      paint,
    );
  }

  static double combine(double first, double second) {
    if (first == 0) return second;
    if (second == 0) return first;
    final largest = math.max(first, second);
    final ratio = math.min(first, second) / largest;
    return largest * math.sqrt(1 + ratio * ratio);
  }

  // Gaussian contributions beyond three standard deviations are negligible.
  // Round out to preserve the edge of the engine's filter footprint.
  static double outset(double sigma) => (3 * sigma).ceilToDouble();

  ui.ImageFilter filter(double sigma) {
    if (_sigma == sigma && _filter != null) return _filter!;
    _sigma = sigma;
    return _filter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);
  }
}
