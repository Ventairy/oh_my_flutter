part of 'morph.dart';

/// Information available when describing one end of a Morph transition.
///
/// Custom flight delegates use these values to describe how the child should
/// look at this location.
@immutable
final class MorphEndpointContext {
  const MorphEndpointContext._({
    required this.context,
    required this.child,
    required RenderBox internalRenderObject,
    required this.localSize,
    required this.overlayBounds,
    required this._transform,
    required this.axisScale,
  }) : _renderObject = internalRenderObject;

  // Built-in compound delegates use this to resolve direct-child layout. It is
  // intentionally unavailable to custom delegates.
  final RenderBox _renderObject;

  /// Context used to resolve inherited values for [child].
  ///
  /// Read inherited values synchronously while
  /// [MorphFlightDelegate.properties] is running. Do not retain this context
  /// for later work.
  final BuildContext context;

  /// The widget supplied to [Morph.child].
  final Widget child;

  /// Size of [child] at this location.
  final Size localSize;

  /// Bounds of [child] in the transition's coordinate system.
  final Rect overlayBounds;

  final Matrix4 _transform;

  /// Transform that places [child] at this location.
  ///
  /// The returned matrix is an independent copy. Changing it does not alter
  /// the captured endpoint.
  Matrix4 get transform => Matrix4.copy(_transform);

  /// Horizontal and vertical scale applied to [child] at this location.
  final Offset axisScale;

  bool get _hasSupportedBuiltInTransform {
    final values = _transform.storage;
    const tolerance = 0.000001;
    bool isZero(double value) => value.abs() <= tolerance;
    bool isOne(double value) => (value - 1).abs() <= tolerance;

    return values[0] > 0 &&
        values[5] > 0 &&
        isZero(values[1]) &&
        isZero(values[2]) &&
        isZero(values[3]) &&
        isZero(values[4]) &&
        isZero(values[6]) &&
        isZero(values[7]) &&
        isZero(values[8]) &&
        isZero(values[9]) &&
        isOne(values[10]) &&
        isZero(values[11]) &&
        isZero(values[14]) &&
        isOne(values[15]);
  }
}
