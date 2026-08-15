part of 'morph.dart';

@immutable
final class _MorphTextRasterPoolKey {
  const _MorphTextRasterPoolKey({
    required this.viewId,
    required this.viewDevicePixelRatio,
    required this.rasterDevicePixelRatio,
    required this.rasterWidth,
    required this.rasterHeight,
    required this.layoutWidth,
    required this.padding,
    required this.text,
    required this.rasterStyle,
    required this.textAlign,
    required this.textDirection,
    required this.locale,
    required this.softWrap,
    required this.overflow,
    required this.textScaler,
    required this.maxLines,
    required this.textWidthBasis,
    required this.textHeightBehavior,
    required this.strutStyle,
  });

  final int viewId;
  final double viewDevicePixelRatio;
  final double rasterDevicePixelRatio;
  final int rasterWidth;
  final int rasterHeight;
  final double layoutWidth;
  final double padding;
  final String text;
  final TextStyle rasterStyle;
  final TextAlign? textAlign;
  final TextDirection textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler textScaler;
  final int? maxLines;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final StrutStyle? strutStyle;

  int get pixels => rasterWidth * rasterHeight;

  @override
  bool operator ==(Object other) {
    return other is _MorphTextRasterPoolKey &&
        viewId == other.viewId &&
        viewDevicePixelRatio == other.viewDevicePixelRatio &&
        rasterDevicePixelRatio == other.rasterDevicePixelRatio &&
        rasterWidth == other.rasterWidth &&
        rasterHeight == other.rasterHeight &&
        layoutWidth == other.layoutWidth &&
        padding == other.padding &&
        text == other.text &&
        rasterStyle == other.rasterStyle &&
        textAlign == other.textAlign &&
        textDirection == other.textDirection &&
        locale == other.locale &&
        softWrap == other.softWrap &&
        overflow == other.overflow &&
        textScaler == other.textScaler &&
        maxLines == other.maxLines &&
        textWidthBasis == other.textWidthBasis &&
        textHeightBehavior == other.textHeightBehavior &&
        strutStyle == other.strutStyle;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    viewId,
    viewDevicePixelRatio,
    rasterDevicePixelRatio,
    rasterWidth,
    rasterHeight,
    layoutWidth,
    padding,
    text,
    rasterStyle,
    textAlign,
    textDirection,
    locale,
    softWrap,
    overflow,
    textScaler,
    maxLines,
    textWidthBasis,
    textHeightBehavior,
    strutStyle,
  ]);
}
