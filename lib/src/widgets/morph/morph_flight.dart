part of 'morph.dart';

/// Values available while building a custom Morph transition.
final class MorphFlight<T> {
  /// Creates the values passed to [MorphFlightDelegate.buildFlight].
  MorphFlight({
    required MorphEndpoint<T> source,
    required MorphEndpoint<T> destination,
    required this.kind,
    required this.animation,
    required MorphFlightDelegate<T> flightDelegate,
  }) : _sourceSnapshot = source,
       _destinationSnapshot = destination,
       _interpolate = ((progress) => flightDelegate.lerp(
         source.properties,
         destination.properties,
         progress,
       ));

  final T Function(double progress) _interpolate;
  double? _cachedPropertiesProgress;
  late T _cachedProperties;
  _MorphFlightGeometry? _geometry;

  // The endpoint represented when [animation] is at zero.
  final MorphEndpoint<T> _sourceSnapshot;

  T get _sourceProperties => _sourceSnapshot.properties;

  /// Current source values and location.
  MorphEndpoint<T> get source => _geometry?.source(_sourceSnapshot.properties) ?? _copySnapshot(_sourceSnapshot);

  // The endpoint represented when [animation] is at one.
  final MorphEndpoint<T> _destinationSnapshot;

  T get _destinationProperties => _destinationSnapshot.properties;

  /// Current destination values and location.
  MorphEndpoint<T> get destination =>
      _geometry?.destination(_destinationSnapshot.properties) ?? _copySnapshot(_destinationSnapshot);

  /// Why the transition started.
  final MorphFlightKind kind;

  /// Curved progress from [source] to [destination].
  ///
  /// The value normally moves from 0 to 1. An overshooting curve can produce
  /// values outside that interval.
  final Animation<double> animation;

  /// The interpolated properties at the current animation progress.
  T get properties {
    final progress = animation.value;
    if (_cachedPropertiesProgress == progress) return _cachedProperties;

    _cachedPropertiesProgress = progress;
    return _cachedProperties = _interpolate(progress);
  }

  /// Current bounds of the shared element.
  Rect get bounds => Rect.lerp(
    _geometry?.sourceBounds ?? _sourceSnapshot.bounds,
    _geometry?.destinationBounds ?? _destinationSnapshot.bounds,
    animation.value,
  )!;

  MorphEndpoint<T> _copySnapshot(MorphEndpoint<T> endpoint) {
    return MorphEndpoint<T>(
      properties: endpoint.properties,
      bounds: endpoint.bounds,
      localSize: endpoint.localSize,
      transform: Matrix4.copy(endpoint.transform),
      axisScale: endpoint.axisScale,
    );
  }
}
