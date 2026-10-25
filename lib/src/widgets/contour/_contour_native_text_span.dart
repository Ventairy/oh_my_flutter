part of 'contour.dart';

// The source text, fonts, scaling, constraints, and paragraph settings are fixed
// by shapeKey. Only our fill color or round stroke Paint changes between these spans.
// Foreground is generally layout damage, but these controlled changes keep
// the verified glyph positions. Report paint damage through InlineSpan's public comparison
// hook so TextPainter can retain its already verified line geometry.
class _ContourNativeTextSpan extends TextSpan {
  new({required this.shapeKey, required TextSpan source})
    : super(text: source.text, style: source.style, children: source.children, locale: source.locale);
  final Object shapeKey;
  @override
  RenderComparison compareTo(InlineSpan other) {
    if (identical(this, other)) return RenderComparison.identical;
    return other is _ContourNativeTextSpan && shapeKey == other.shapeKey
        ? RenderComparison.paint
        : RenderComparison.layout;
  }
}
