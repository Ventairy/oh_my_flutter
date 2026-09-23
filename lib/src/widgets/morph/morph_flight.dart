part of 'morph.dart';

/// Customize a shared element throughout a Morph transition.
///
/// See the [Morph guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph.md#build-a-custom-flight)
/// for custom transition examples.
final class MorphFlight<T> {
  /// Creates the values passed to [MorphFlightDelegate.buildFlight].
  new({
    required MorphEndpoint<T> source,
    required MorphEndpoint<T> destination,
    required MorphFlightKind kind,
    required Animation<double> curvedAnimation,
    required Animation<double> uncurvedAnimation,
    required MorphFlightDelegate<T> flightDelegate,
  }) : this._(
         source: source,
         destination: destination,
         kind: kind,
         curvedAnimation: curvedAnimation,
         uncurvedAnimation: uncurvedAnimation,
         flightDelegate: flightDelegate,
         endpointState: null,
         resolveEndpointProperties: null,
       );

  new _({
    required MorphEndpoint<T> source,
    required MorphEndpoint<T> destination,
    required this.kind,
    required Animation<double> curvedAnimation,
    required Animation<double> uncurvedAnimation,
    required this._flightDelegate,
    required _MorphFlightGeometry? endpointState,
    required T Function(Object? properties)? resolveEndpointProperties,
  }) : _sourceSnapshot = source,
       _destinationSnapshot = destination,
       _resolveEndpointProperties = resolveEndpointProperties ?? ((properties) => properties as T),
       curvedAnimation = _morphEndpointAwareAnimation(curvedAnimation, endpointState),
       uncurvedAnimation = _morphEndpointAwareAnimation(uncurvedAnimation, endpointState),
       _geometry = endpointState;

  final MorphFlightDelegate<T> _flightDelegate;
  final T Function(Object? properties) _resolveEndpointProperties;
  MorphFlightProgress? _cachedPropertiesProgress;
  int? _cachedPropertiesRevision;
  late T _cachedProperties;
  final _MorphFlightGeometry? _geometry;

  // The endpoint represented when [curvedAnimation] is at zero.
  final MorphEndpoint<T> _sourceSnapshot;

  T get _sourceProperties {
    final endpointState = _geometry;
    return endpointState == null
        ? _sourceSnapshot.properties
        : _resolveEndpointProperties(endpointState.sourceProperties);
  }

  /// Current source values and location.
  MorphEndpoint<T> get source {
    final endpointState = _geometry;
    if (endpointState == null) return _copySnapshot(_sourceSnapshot);
    return _copyCurrentEndpoint(endpointState.source<Object?>());
  }

  // The endpoint represented when [curvedAnimation] is at one.
  final MorphEndpoint<T> _destinationSnapshot;

  T get _destinationProperties {
    final endpointState = _geometry;
    return endpointState == null
        ? _destinationSnapshot.properties
        : _resolveEndpointProperties(endpointState.destinationProperties);
  }

  /// Current destination values and location.
  MorphEndpoint<T> get destination {
    final endpointState = _geometry;
    if (endpointState == null) return _copySnapshot(_destinationSnapshot);
    return _copyCurrentEndpoint(endpointState.destination<Object?>());
  }

  /// Why the transition started.
  final MorphFlightKind kind;

  /// Follow the shared element with the current direction's target curve.
  ///
  /// Drives [properties] and [bounds] from [source] to [destination].
  /// The value normally moves from 0 to 1. An overshooting curve can produce
  /// values outside that interval.
  final Animation<double> curvedAnimation;

  /// Give custom content its own timing and easing, unaffected by [MorphTarget.curve].
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
    final revision = _geometry?.revision ?? 0;
    if (_cachedPropertiesProgress == progress && _cachedPropertiesRevision == revision) {
      return _cachedProperties;
    }

    _cachedPropertiesProgress = progress;
    _cachedPropertiesRevision = revision;
    return _cachedProperties = _flightDelegate.lerpProperties(
      _sourceProperties,
      _destinationProperties,
      progress,
    );
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

  MorphEndpoint<T> _copyCurrentEndpoint(MorphEndpoint<Object?> endpoint) {
    return _MorphDescendantSnapshots.copy(
      endpoint,
      MorphEndpoint<T>(
        properties: _resolveEndpointProperties(endpoint.properties),
        bounds: endpoint.bounds,
        localSize: endpoint.localSize,
        transform: Matrix4.copy(endpoint.transform),
        axisScale: endpoint.axisScale,
      ),
    );
  }
}
