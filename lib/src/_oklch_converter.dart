part of 'omf_oklch.dart';

final class _OklchConverter {
  _OklchConverter._();

  static OmfOklch fromColor(Color color) {
    final r = _toLinear((color.r * 255).round());
    final g = _toLinear((color.g * 255).round());
    final b = _toLinear((color.b * 255).round());

    final l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
    final m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
    final s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

    final l_ = _cbrt(l);
    final m_ = _cbrt(m);
    final s_ = _cbrt(s);

    final L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_;
    final a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_;
    final b_ = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_;

    final C = math.sqrt(a * a + b_ * b_);
    final H = math.atan2(b_, a) * 180 / math.pi;

    return OmfOklch(L, C, (H + 360) % 360);
  }

  static Color toColor(double l, double c, double h) {
    final (r, g, b) = _toLinearRgb(l, c, h);
    return _linearRgbToColor(r, g, b);
  }

  static double _toLinear(int channel) {
    final v = channel / 255.0;
    if (v <= 0.04045) return v / 12.92;
    return math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  static int _fromLinear(double v) {
    final s = v <= 0.0031308 ? 12.92 * v : 1.055 * math.pow(v, 1.0 / 2.4) - 0.055;
    return (s * 255).round().clamp(0, 255);
  }

  static double _cbrt(double x) {
    if (x < 0) return -math.pow(-x, 1.0 / 3.0).toDouble();
    return math.pow(x, 1.0 / 3.0).toDouble();
  }

  static (double, double, double) _toLinearRgb(double l, double c, double h) {
    final hRad = h * math.pi / 180;
    final a = c * math.cos(hRad);
    final b = c * math.sin(hRad);

    final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = l - 0.0894841775 * a - 1.2914855480 * b;

    final l3 = l_ * l_ * l_;
    final m3 = m_ * m_ * m_;
    final s3 = s_ * s_ * s_;

    final r = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3;
    final g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3;
    final b_ = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3;

    return (r, g, b_);
  }

  static Color _linearRgbToColor(double r, double g, double b) {
    return Color.fromARGB(255, _fromLinear(r), _fromLinear(g), _fromLinear(b));
  }
}
