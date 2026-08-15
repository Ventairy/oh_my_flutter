part of 'morph.dart';

@immutable
/// Visual values for a container at one end of a Morph transition.
final class MorphContainerProperties {
  /// Creates the visual values for a container.
  const MorphContainerProperties({
    required this.alignment,
    required this.padding,
    required this.decoration,
    required this.foregroundDecoration,
    required this.clipBehavior,
    required this.child,
    required this.switchThreshold,
  });

  /// Alignment of the container's child.
  final Alignment? alignment;

  /// Padding around the container's child.
  final EdgeInsets padding;

  /// Background decoration.
  final Decoration? decoration;

  /// Foreground decoration.
  final Decoration? foregroundDecoration;

  /// How content outside the container is clipped.
  final Clip clipBehavior;

  /// Visual values for the container's child, if it has one.
  final MorphChildProperties? child;

  /// Progress at which non-interpolated values switch to the destination.
  final double switchThreshold;
}
