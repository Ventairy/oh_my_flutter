part of 'morph.dart';

/// Describes how a shared element looks at one end of a [MorphFlight].
@immutable
final class MorphEndpoint<T> {
  /// Creates a description of one end of a Morph transition.
  const MorphEndpoint({
    required this.properties,
    required this.bounds,
    required this.localSize,
    required this.transform,
    required this.axisScale,
  });

  /// Visual values supplied by the flight delegate.
  final T properties;

  /// Bounds of the shared element in the transition's coordinate system.
  final Rect bounds;

  /// Resting size of the shared element.
  final Size localSize;

  /// Transform that places the shared element at this location.
  final Matrix4 transform;

  /// Horizontal and vertical scale at this location.
  final Offset axisScale;
}
