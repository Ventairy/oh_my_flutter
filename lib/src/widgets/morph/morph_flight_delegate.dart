part of 'morph.dart';

/// Defines how a custom shared element changes during a Morph transition.
///
/// Subclass this type when Morph's automatic transition does not provide the
/// visual you want. The type parameter represents the visual values available
/// at each end of the transition.
abstract class MorphFlightDelegate<T> {
  /// Creates a delegate for a custom Morph transition.
  const MorphFlightDelegate();

  /// Returns the visual values for [endpoint].
  T properties(MorphEndpointContext endpoint);

  /// Returns the visual values between [source] and [destination] at [progress].
  ///
  /// [progress] follows [MorphFlight.animation] and can fall outside the 0 to 1
  /// interval when the configured curve overshoots.
  T lerp(T source, T destination, double progress);

  /// Builds the widget shown during the transition.
  ///
  /// Use [flight] to read the current properties, bounds, progress, and reason
  /// for the transition. This method is not called for every progress change.
  /// Listen to [MorphFlight.animation], for example with an AnimatedBuilder or
  /// transition widget, when the returned widget reads changing flight values.
  Widget buildFlight(BuildContext context, MorphFlight<T> flight);

  MorphEndpoint<Object?> _interpolateEndpoint(
    MorphEndpoint<Object?> source,
    MorphEndpoint<Object?> destination, {
    required double progress,
  }) {
    return MorphEndpoint<Object?>(
      properties: lerp(
        source.properties as T,
        destination.properties as T,
        progress,
      ),
      bounds: Rect.lerp(
        source.bounds,
        destination.bounds,
        progress,
      )!,
      localSize: Size.lerp(
        source.localSize,
        destination.localSize,
        progress,
      )!,
      transform: Matrix4Tween(
        begin: source.transform,
        end: destination.transform,
      ).lerp(progress),
      axisScale: Offset.lerp(
        source.axisScale,
        destination.axisScale,
        progress,
      )!,
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
      source: MorphEndpoint<T>(
        properties: source.properties as T,
        bounds: source.bounds,
        localSize: source.localSize,
        transform: source.transform,
        axisScale: source.axisScale,
      ),
      destination: MorphEndpoint<T>(
        properties: destination.properties as T,
        bounds: destination.bounds,
        localSize: destination.localSize,
        transform: destination.transform,
        axisScale: destination.axisScale,
      ),
      kind: flight.kind,
      animation: flight.animation,
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
