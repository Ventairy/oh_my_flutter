part of 'morph.dart';

@immutable
/// Visual values for a child inside a container or column transition.
final class MorphChildProperties {
  /// Creates the visual values for a child.
  const MorphChildProperties({
    required this.widget,
    required this.rect,
    required this.padding,
    required this.alignment,
    required this.explicitSize,
    required this.text,
    required this.container,
    required this.column,
    required this.key,
    required this._capturedThemes,
    required this._mediaQueryData,
    this._transitionProgress = 1,
  });

  final CapturedThemes? _capturedThemes;
  final MediaQueryData? _mediaQueryData;
  final double _transitionProgress;

  /// Widget shown when no specialized transition is available.
  final Widget widget;

  /// Child bounds within its parent.
  final Rect rect;

  /// Padding around the child.
  final EdgeInsets padding;

  /// Alignment applied around the child, if any.
  final Alignment? alignment;

  /// Explicit width and height applied around the child, if any.
  final Size? explicitSize;

  /// Text values when the child is plain text.
  final MorphTextProperties? text;

  /// Container values when the child is a container.
  final MorphContainerProperties? container;

  /// Column values when the child is a vertical column.
  final MorphColumnProperties? column;

  /// Key used to match this child with its counterpart.
  final Key? key;

  MorphChildProperties _withTransitionProgress(double progress) {
    return MorphChildProperties(
      widget: widget,
      rect: rect,
      padding: padding,
      alignment: alignment,
      explicitSize: explicitSize,
      text: text,
      container: container,
      column: column,
      key: key,
      capturedThemes: _capturedThemes,
      mediaQueryData: _mediaQueryData,
      transitionProgress: progress,
    );
  }
}
