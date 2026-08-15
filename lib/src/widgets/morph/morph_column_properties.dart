part of 'morph.dart';

@immutable
/// Visual values for a vertical column at one end of a Morph transition.
final class MorphColumnProperties {
  /// Creates the visual values for a vertical column.
  const MorphColumnProperties({
    required this.children,
    required this.switchThreshold,
  });

  /// Direct children and their resting positions.
  final List<MorphChildProperties> children;

  /// Progress at which matched children switch non-interpolated values to the
  /// destination.
  final double switchThreshold;
}
