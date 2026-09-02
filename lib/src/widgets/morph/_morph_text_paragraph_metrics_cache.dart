part of 'morph.dart';

final class _MorphTextParagraphMetricsCache {
  ({Object key, ({double baseline, double height, double lineHeight}) metrics})? _source;
  ({Object key, ({double baseline, double height, double lineHeight}) metrics})? _destination;

  ({double baseline, double height, double lineHeight}) measure({
    required MorphTextProperties properties,
    required TextStyle paintStyle,
    required double layoutWidth,
    required bool sourceSegment,
  }) {
    final key = (
      properties.text,
      paintStyle,
      layoutWidth,
      properties.textAlign,
      properties.textDirection,
      properties.textScaler,
      properties.locale,
      properties.softWrap,
      properties.overflow,
      properties.maxLines,
      properties.textWidthBasis,
      properties.textHeightBehavior,
      properties.strutStyle,
    );
    final cached = sourceSegment ? _source : _destination;
    if (cached?.key == key) return cached!.metrics;

    final painter = TextPainter(
      text: TextSpan(text: properties.text, style: paintStyle),
      textAlign: properties.textAlign ?? TextAlign.start,
      textDirection: properties.textDirection,
      textScaler: properties.textScaler,
      locale: properties.locale,
      textWidthBasis: properties.textWidthBasis ?? TextWidthBasis.parent,
      textHeightBehavior: properties.textHeightBehavior,
      strutStyle: properties.strutStyle,
      maxLines: properties.maxLines,
      ellipsis: properties.overflow == TextOverflow.ellipsis ? '…' : null,
    );
    try {
      painter.layout(
        maxWidth: (properties.softWrap ?? true) || properties.overflow == TextOverflow.ellipsis
            ? layoutWidth
            : double.infinity,
      );
      final firstLine = painter.computeLineMetrics().firstOrNull;
      final metrics = (
        baseline: firstLine?.baseline ?? 0,
        height: painter.height,
        lineHeight: firstLine?.height ?? painter.preferredLineHeight,
      );
      final entry = (key: key, metrics: metrics);
      if (sourceSegment) {
        _source = entry;
      } else {
        _destination = entry;
      }
      return metrics;
    } finally {
      painter.dispose();
    }
  }

  void clear() {
    _source = null;
    _destination = null;
  }
}
