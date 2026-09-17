part of 'morph.dart';

/// Defines how a custom shared element changes during a Morph transition.
///
/// Subclass this type when Morph's automatic transition does not provide the
/// visual you want, then pass an instance to [MorphFlightConfig.custom]. The
/// type parameter represents the visual values available at each end of the
/// transition.
///
/// See the [Morph guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph.md#build-a-custom-flight)
/// for a complete custom transition example.
abstract class MorphFlightDelegate<T> {
  /// Creates a delegate for a custom Morph transition.
  const MorphFlightDelegate();

  /// Returns the visual values for [endpoint].
  ///
  /// Register endpoint widget content with
  /// [MorphEndpointContext.descendantWidget] here, store the returned
  /// widgets in your properties, and build those widgets in the flight.
  T properties(MorphEndpointContext endpoint);

  /// Returns the visual values between [source] and [destination] at [progress].
  ///
  /// Use [MorphFlightProgress.curvedProgress] to follow the surface's curve,
  /// or apply a content curve to [MorphFlightProgress.uncurvedProgress] for
  /// independent timing. Curved progress may overshoot the endpoint range.
  T lerpProperties(T source, T destination, MorphFlightProgress progress);

  /// Builds the widget shown during the transition.
  ///
  /// Use [flight] to read the current properties, bounds, progress, and reason
  /// for the transition. This method is not called for every progress change.
  /// Listen to [MorphFlight.curvedAnimation] when the returned widget reads
  /// changing properties or bounds. Use [MorphFlight.uncurvedAnimation] to give
  /// content its own timing and easing. An AnimatedBuilder or transition widget
  /// can listen to either animation.
  Widget buildFlight(BuildContext context, MorphFlight<T> flight);

  MorphEndpoint<Object?> _interpolateEndpoint(
    MorphEndpoint<Object?> source,
    MorphEndpoint<Object?> destination, {
    required MorphFlightProgress progress,
  }) {
    return _MorphDescendantSnapshots.combine(
      source,
      destination,
      MorphEndpoint<Object?>(
        properties: lerpProperties(
          source.properties as T,
          destination.properties as T,
          progress,
        ),
        bounds: Rect.lerp(
          source.bounds,
          destination.bounds,
          progress.curvedProgress,
        )!,
        localSize: Size.lerp(
          source.localSize,
          destination.localSize,
          progress.curvedProgress,
        )!,
        transform: Matrix4Tween(
          begin: source.transform,
          end: destination.transform,
        ).lerp(progress.curvedProgress),
        axisScale: Offset.lerp(
          source.axisScale,
          destination.axisScale,
          progress.curvedProgress,
        )!,
      ),
    );
  }

  Widget _buildErasedFlight(
    BuildContext context,
    MorphFlight<Object?> flight, {
    _MorphTextRasterPool? rasterPool,
  }) {
    final source = flight.source;
    final destination = flight.destination;
    final typedFlight = MorphFlight<T>(
      source: _MorphDescendantSnapshots.copy(
        source,
        MorphEndpoint<T>(
          properties: source.properties as T,
          bounds: source.bounds,
          localSize: source.localSize,
          transform: source.transform,
          axisScale: source.axisScale,
        ),
      ),
      destination: _MorphDescendantSnapshots.copy(
        destination,
        MorphEndpoint<T>(
          properties: destination.properties as T,
          bounds: destination.bounds,
          localSize: destination.localSize,
          transform: destination.transform,
          axisScale: destination.axisScale,
        ),
      ),
      kind: flight.kind,
      curvedAnimation: flight.curvedAnimation,
      uncurvedAnimation: flight.uncurvedAnimation,
      flightDelegate: this,
    ).._geometry = flight._geometry;
    if (this case final MorphTextFlightDelegate delegate when rasterPool != null) {
      return _MorphTextFlight(
        delegate: delegate,
        flight: typedFlight as MorphFlight<MorphTextProperties>,
        rasterPool: rasterPool,
        geometry: flight._geometry,
      );
    }
    return buildFlight(
      context,
      typedFlight,
    );
  }
}
