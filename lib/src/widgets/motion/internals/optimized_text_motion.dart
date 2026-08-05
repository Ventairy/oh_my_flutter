part of '../motion.dart';

/// Hosts the batched render path used by every motion effect.
class _OptimizedTextMotion extends LeafRenderObjectWidget {
  const _OptimizedTextMotion({
    required this.graphemes,
    required this.applications,
    required this.style,
    required this.strutStyle,
    required this.textAlign,
    required this.textDirection,
    required this.locale,
    required this.softWrap,
    required this.overflow,
    required this.textScaler,
    required this.maxLines,
    required this.textWidthBasis,
    required this.textHeightBehavior,
    required this.baseline,
    required this.devicePixelRatio,
    required this.attributedLabel,
    required this.semanticsIdentifier,
    super.key,
  });

  final List<String> graphemes;

  final List<_TextMotionApplication> applications;

  final TextStyle style;

  final StrutStyle? strutStyle;

  final TextAlign textAlign;

  final TextDirection textDirection;

  final Locale? locale;

  final bool softWrap;

  final TextOverflow overflow;

  final TextScaler textScaler;

  final int? maxLines;

  final TextWidthBasis textWidthBasis;

  final ui.TextHeightBehavior? textHeightBehavior;

  final TextBaseline baseline;

  final double devicePixelRatio;

  final AttributedString attributedLabel;

  final String? semanticsIdentifier;

  @override
  _RenderOptimizedTextMotion createRenderObject(BuildContext context) {
    return _RenderOptimizedTextMotion(
      graphemes: graphemes,
      applications: applications,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      baseline: baseline,
      devicePixelRatio: devicePixelRatio,
      attributedLabel: attributedLabel,
      semanticsIdentifier: semanticsIdentifier,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderOptimizedTextMotion renderObject,
  ) {
    renderObject.updateConfiguration(
      graphemes: graphemes,
      applications: applications,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      baseline: baseline,
      devicePixelRatio: devicePixelRatio,
      attributedLabel: attributedLabel,
      semanticsIdentifier: semanticsIdentifier,
    );
  }
}
