part of 'morph.dart';

@immutable
/// Visual values for plain text at one end of a Morph transition.
final class MorphTextProperties {
  /// Creates the visual values for plain text.
  const MorphTextProperties({
    required this.text,
    required this.style,
    required this.textAlign,
    required this.textDirection,
    required this.locale,
    required this.softWrap,
    required this.overflow,
    required this.textScaler,
    required this.maxLines,
    required this.semanticsLabel,
    required this.textWidthBasis,
    required this.textHeightBehavior,
    required this.strutStyle,
    required this.selectionColor,
    required this.switchThreshold,
    required this.measuredLineCount,
    required this.longestLineWidth,
    required this.lineHeight,
    required this.baseline,
    required this.layoutWidth,
    required this.estimatedHeight,
    required this.paintStyle,
    required this.paintScaleX,
    required this.paintScaleY,
    required this.endpointScaleX,
    required this.endpointScaleY,
    required this.baselineOffset,
    required this.reservedLayoutWidth,
  });

  /// Visible text content.
  final String text;

  /// Text style at this end of the transition.
  final TextStyle style;

  /// Horizontal text alignment.
  final TextAlign? textAlign;

  /// Direction in which the text is read.
  final TextDirection textDirection;

  /// Text locale.
  final Locale? locale;

  /// Whether lines may wrap.
  final bool? softWrap;

  /// Overflow behavior.
  final TextOverflow? overflow;

  /// Scaling policy applied to the text.
  final TextScaler textScaler;

  /// Maximum visible line count.
  final int? maxLines;

  /// Optional accessibility label.
  final String? semanticsLabel;

  /// Width measurement basis.
  final TextWidthBasis? textWidthBasis;

  /// Paragraph height behavior.
  final TextHeightBehavior? textHeightBehavior;

  /// Optional strut configuration.
  final StrutStyle? strutStyle;

  /// Selection highlight color.
  final Color? selectionColor;

  /// Progress at which the visible text and non-interpolated values switch to
  /// the destination.
  final double switchThreshold;

  /// Number of visible lines at this end of the transition.
  final int measuredLineCount;

  /// Width of the widest visible line.
  final double longestLineWidth;

  /// Height of one line of text.
  final double lineHeight;

  /// Alphabetic baseline of the first line.
  final double baseline;

  /// Width available to the text at this end of the transition.
  final double layoutWidth;

  /// Height occupied by the text during the transition.
  final double estimatedHeight;

  /// Style currently shown during the transition.
  final TextStyle paintStyle;

  /// Horizontal scale applied to the visible text.
  final double paintScaleX;

  /// Vertical scale applied to the visible text.
  final double paintScaleY;

  /// Horizontal scale at this end of the transition.
  final double endpointScaleX;

  /// Vertical scale at this end of the transition.
  final double endpointScaleY;

  /// Vertical adjustment that keeps the alphabetic baseline aligned.
  final double baselineOffset;

  /// Width used to keep the currently visible text from wrapping temporarily.
  final double? reservedLayoutWidth;
}
