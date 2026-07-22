part of 'oklch.dart';

final class _OklchConverter {
  _OklchConverter._();

  static const double _achromaticEpsilon = 0.000004;
  static const double _gamutEpsilon = 0.0001;
  static const double _justNoticeableDifference = 0.02;

  static Oklch fromColor(Color color) {
    final (lightness, a, b) = _linearRgbToOklab(
      _toLinear(color.r),
      _toLinear(color.g),
      _toLinear(color.b),
      color.colorSpace,
    );
    final chroma = math.sqrt(a * a + b * b);
    if (chroma <= _achromaticEpsilon) return Oklch(lightness, chroma, 0);

    final hue = math.atan2(b, a) * 180 / math.pi;
    return Oklch(lightness, chroma, (hue + 360) % 360);
  }

  static Color toColor(
    double lightness,
    double chroma,
    double hue, {
    ColorSpace colorSpace = ColorSpace.sRGB,
  }) {
    _validateComponents(lightness: lightness, chroma: chroma, hue: hue);

    final normalizedLightness = lightness.clamp(0, 1).toDouble();
    if (normalizedLightness == 0) {
      return _colorFromChannels(0, 0, 0, colorSpace);
    }
    if (normalizedLightness == 1) {
      return _colorFromChannels(1, 1, 1, colorSpace);
    }

    final normalizedChroma = math.max(0, chroma).toDouble();
    final normalizedHue = ((hue % 360) + 360) % 360;
    final linearRgb = _toLinearRgb(
      normalizedLightness,
      normalizedChroma,
      normalizedHue,
      colorSpace,
    );
    if (colorSpace == ColorSpace.extendedSRGB || _isInGamut(linearRgb)) {
      return _linearRgbToColor(linearRgb, colorSpace);
    }

    return _linearRgbToColor(
      _mapToGamut(
        normalizedLightness,
        normalizedChroma,
        normalizedHue,
        colorSpace,
      ),
      colorSpace,
    );
  }

  static void _validateComponents({
    required double lightness,
    required double chroma,
    required double hue,
  }) {
    if (!lightness.isFinite) {
      throw ArgumentError.value(lightness, 'lightness', 'must be finite');
    }
    if (!chroma.isFinite) {
      throw ArgumentError.value(chroma, 'chroma', 'must be finite');
    }
    if (!hue.isFinite) throw ArgumentError.value(hue, 'hue', 'must be finite');
  }

  static double _toLinear(double channel) {
    if (channel <= 0.04045) return channel / 12.92;
    return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  static double _fromLinear(double channel, {required bool clamp}) {
    final encoded = channel <= 0.0031308 ? 12.92 * channel : 1.055 * math.pow(channel, 1 / 2.4) - 0.055;
    if (!clamp) return encoded;
    return encoded.clamp(0.0, 1.0);
  }

  static double _cbrt(double value) {
    if (value < 0) return -math.pow(-value, 1 / 3).toDouble();
    return math.pow(value, 1 / 3).toDouble();
  }

  static (double, double, double) _linearRgbToOklab(
    double red,
    double green,
    double blue,
    ColorSpace colorSpace,
  ) {
    switch (colorSpace) {
      case ColorSpace.sRGB:
      case ColorSpace.extendedSRGB:
        return _linearSrgbToOklab(red, green, blue);
      case ColorSpace.displayP3:
        final x = 0.4865709486482162 * red + 0.26566769316909306 * green + 0.1982172852343625 * blue;
        final y = 0.2289745640697488 * red + 0.6917385218365064 * green + 0.079286914093745 * blue;
        final z = 0.0 * red + 0.04511338185890264 * green + 1.043944368900976 * blue;
        return _xyzToOklab(x, y, z);
    }
  }

  static (double, double, double) _linearSrgbToOklab(
    double red,
    double green,
    double blue,
  ) {
    final l = 0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue;
    final m = 0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue;
    final s = 0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue;

    final lRoot = _cbrt(l);
    final mRoot = _cbrt(m);
    final sRoot = _cbrt(s);

    return (
      0.2104542553 * lRoot + 0.7936177850 * mRoot - 0.0040720468 * sRoot,
      1.9779984951 * lRoot - 2.4285922050 * mRoot + 0.4505937099 * sRoot,
      0.0259040371 * lRoot + 0.7827717662 * mRoot - 0.8086757660 * sRoot,
    );
  }

  static (double, double, double) _xyzToOklab(double x, double y, double z) {
    final lRoot = _cbrt(
      0.819022437996703 * x + 0.3619062600528904 * y - 0.1288737815209879 * z,
    );
    final mRoot = _cbrt(
      0.0329836539323885 * x + 0.9292868615863434 * y + 0.0361446663506424 * z,
    );
    final sRoot = _cbrt(
      0.0481771893596242 * x + 0.2642395317527308 * y + 0.6335478284694309 * z,
    );

    return (
      0.2104542553 * lRoot + 0.7936177850 * mRoot - 0.0040720468 * sRoot,
      1.9779984951 * lRoot - 2.4285922050 * mRoot + 0.4505937099 * sRoot,
      0.0259040371 * lRoot + 0.7827717662 * mRoot - 0.8086757660 * sRoot,
    );
  }

  static (double, double, double) _toLinearRgb(
    double lightness,
    double chroma,
    double hue,
    ColorSpace colorSpace,
  ) {
    final hueRadians = hue * math.pi / 180;
    final a = chroma * math.cos(hueRadians);
    final b = chroma * math.sin(hueRadians);

    final lRoot = lightness + 0.3963377774 * a + 0.2158037573 * b;
    final mRoot = lightness - 0.1055613458 * a - 0.0638541728 * b;
    final sRoot = lightness - 0.0894841775 * a - 1.2914855480 * b;

    final l = lRoot * lRoot * lRoot;
    final m = mRoot * mRoot * mRoot;
    final s = sRoot * sRoot * sRoot;

    final linearSrgb = (
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    );
    switch (colorSpace) {
      case ColorSpace.sRGB:
      case ColorSpace.extendedSRGB:
        return linearSrgb;
      case ColorSpace.displayP3:
        final x =
            0.41239079926595934 * linearSrgb.$1 +
            0.357584339383878 * linearSrgb.$2 +
            0.1804807884018343 * linearSrgb.$3;
        final y =
            0.21263900587151027 * linearSrgb.$1 +
            0.715168678767756 * linearSrgb.$2 +
            0.07219231536073371 * linearSrgb.$3;
        final z =
            0.01933081871559182 * linearSrgb.$1 +
            0.11919477979462598 * linearSrgb.$2 +
            0.9505321522496607 * linearSrgb.$3;
        return (
          2.493496911941425 * x - 0.9313836179191239 * y - 0.40271078445071684 * z,
          -0.8294889695615747 * x + 1.7626640603183463 * y + 0.023624685841943577 * z,
          0.03584583024378447 * x - 0.07617238926804182 * y + 0.9568845240076872 * z,
        );
    }
  }

  static bool _isInGamut((double, double, double) linearRgb) {
    final (red, green, blue) = linearRgb;
    return red >= 0 && red <= 1 && green >= 0 && green <= 1 && blue >= 0 && blue <= 1;
  }

  static (double, double, double) _mapToGamut(
    double lightness,
    double chroma,
    double hue,
    ColorSpace colorSpace,
  ) {
    var minimumChroma = 0.0;
    var maximumChroma = chroma;
    var minimumIsInGamut = true;
    var clipped = _clipLinearRgb(
      _toLinearRgb(lightness, chroma, hue, colorSpace),
    );

    while (maximumChroma - minimumChroma > _gamutEpsilon) {
      final currentChroma = (minimumChroma + maximumChroma) / 2;
      final current = _toLinearRgb(lightness, currentChroma, hue, colorSpace);
      if (minimumIsInGamut && _isInGamut(current)) {
        minimumChroma = currentChroma;
        continue;
      }

      clipped = _clipLinearRgb(current);
      final difference = _deltaEok(
        lightness,
        currentChroma,
        hue,
        _linearRgbToOklab(clipped.$1, clipped.$2, clipped.$3, colorSpace),
      );
      if (difference < _justNoticeableDifference) {
        if (_justNoticeableDifference - difference < _gamutEpsilon) {
          return clipped;
        }
        minimumIsInGamut = false;
        minimumChroma = currentChroma;
        continue;
      }

      maximumChroma = currentChroma;
    }

    return clipped;
  }

  static double _deltaEok(
    double lightness,
    double chroma,
    double hue,
    (double, double, double) clippedOklab,
  ) {
    final hueRadians = hue * math.pi / 180;
    final a = chroma * math.cos(hueRadians);
    final b = chroma * math.sin(hueRadians);
    final lightnessDifference = lightness - clippedOklab.$1;
    final aDifference = a - clippedOklab.$2;
    final bDifference = b - clippedOklab.$3;
    return math.sqrt(
      lightnessDifference * lightnessDifference + aDifference * aDifference + bDifference * bDifference,
    );
  }

  static (double, double, double) _clipLinearRgb(
    (double, double, double) linearRgb,
  ) {
    return (
      linearRgb.$1.clamp(0.0, 1.0),
      linearRgb.$2.clamp(0.0, 1.0),
      linearRgb.$3.clamp(0.0, 1.0),
    );
  }

  static Color _linearRgbToColor(
    (double, double, double) linearRgb,
    ColorSpace colorSpace,
  ) {
    final shouldClamp = colorSpace != ColorSpace.extendedSRGB;
    return _colorFromChannels(
      _fromLinear(linearRgb.$1, clamp: shouldClamp),
      _fromLinear(linearRgb.$2, clamp: shouldClamp),
      _fromLinear(linearRgb.$3, clamp: shouldClamp),
      colorSpace,
    );
  }

  static Color _colorFromChannels(
    double red,
    double green,
    double blue,
    ColorSpace colorSpace,
  ) {
    return Color.from(
      alpha: 1,
      red: red,
      green: green,
      blue: blue,
      colorSpace: colorSpace,
    );
  }
}
