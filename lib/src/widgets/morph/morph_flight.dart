part of 'morph.dart';

/// Customize a shared element throughout a Morph transition.
///
/// See the [Morph guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph.md#build-a-custom-flight)
/// for custom transition examples.
final class MorphFlight<T> {
  /// Creates the values passed to [MorphFlightDelegate.buildFlight].
  MorphFlight({
    required MorphEndpoint<T> source,
    required MorphEndpoint<T> destination,
    required this.kind,
    required this.curvedAnimation,
    required this.uncurvedAnimation,
    required MorphFlightDelegate<T> flightDelegate,
  }) : _sourceSnapshot = source,
       _destinationSnapshot = destination,
       _interpolate = ((progress) => flightDelegate.lerpProperties(
         source.properties,
         destination.properties,
         progress,
       ));

  final T Function(MorphFlightProgress progress) _interpolate;
  MorphFlightProgress? _cachedPropertiesProgress;
  late T _cachedProperties;
  _MorphFlightGeometry? _geometry;

  // The endpoint represented when [curvedAnimation] is at zero.
  final MorphEndpoint<T> _sourceSnapshot;

  T get _sourceProperties => _sourceSnapshot.properties;

  /// Current source values and location.
  MorphEndpoint<T> get source => _geometry?.source(_sourceSnapshot.properties) ?? _copySnapshot(_sourceSnapshot);

  // The endpoint represented when [curvedAnimation] is at one.
  final MorphEndpoint<T> _destinationSnapshot;

  T get _destinationProperties => _destinationSnapshot.properties;

  /// Current destination values and location.
  MorphEndpoint<T> get destination =>
      _geometry?.destination(_destinationSnapshot.properties) ?? _copySnapshot(_destinationSnapshot);

  /// Why the transition started.
  final MorphFlightKind kind;

  /// Follow the shared element's movement and appearance with [Morph.curve].
  ///
  /// Drives [properties] and [bounds] from [source] to [destination].
  /// The value normally moves from 0 to 1. An overshooting curve can produce
  /// values outside that interval.
  final Animation<double> curvedAnimation;

  /// Give custom content its own timing and easing, unaffected by [Morph.curve].
  ///
  /// Shares the flight's progress and playback direction with [curvedAnimation],
  ///
  /// When the flight follows a route animation, its progress may already be
  /// curved or controlled by a gesture. It is therefore not always a linear
  /// measure of elapsed time.
  final Animation<double> uncurvedAnimation;

  MorphFlightProgress get _progress => MorphFlightProgress(
    curvedProgress: curvedAnimation.value,
    uncurvedProgress: uncurvedAnimation.value,
    flightKind: kind,
    animationStatus: uncurvedAnimation.status,
  );

  /// The interpolated visual values at the current flight timing.
  T get properties {
    final progress = _progress;
    if (_cachedPropertiesProgress == progress) return _cachedProperties;

    _cachedPropertiesProgress = progress;
    return _cachedProperties = _interpolate(progress);
  }

  /// Current bounds of the shared element, following [curvedAnimation].
  Rect get bounds => Rect.lerp(
    _geometry?.sourceBounds ?? _sourceSnapshot.bounds,
    _geometry?.destinationBounds ?? _destinationSnapshot.bounds,
    curvedAnimation.value,
  )!;

  MorphEndpoint<T> _copySnapshot(MorphEndpoint<T> endpoint) {
    return _MorphDescendantSnapshots.copy(
      endpoint,
      MorphEndpoint<T>(
        properties: endpoint.properties,
        bounds: endpoint.bounds,
        localSize: endpoint.localSize,
        transform: Matrix4.copy(endpoint.transform),
        axisScale: endpoint.axisScale,
      ),
    );
  }
}
