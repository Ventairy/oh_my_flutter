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
    required this._descendantCapture,
  }) : _renderObject = internalRenderObject;

  // Built-in compound delegates use this to resolve direct-child layout. It is
  // intentionally unavailable to custom delegates.
  final RenderBox _renderObject;
  final _MorphDescendantCapture _descendantCapture;

  /// Context used to resolve inherited values for [child].
  ///
  /// Read inherited values synchronously while
  /// [MorphFlightDelegate.properties] is running. Do not retain this context
  /// for later work.
  final BuildContext context;

  /// The widget supplied to [Morph.child].
  final Widget child;

  /// Prepares an endpoint's widget content for use in a custom flight.
  ///
  /// Call this for each endpoint subtree used by the flight, from
  /// [MorphFlightDelegate.properties]. Store the returned widget in your
  /// properties and build it in the flight. You can register several subtrees
  /// and select or animate each independently with ordinary Flutter widgets.
  ///
  /// Registration is the standard approach and is highly recommended for
  /// better compatibility. Content may work without it.
  ///
  /// Register the complete subtree, including any [MorphDescendant] wrappers.
  /// If indistinguishable descendants occur several times within one registered
  /// subtree, give their MorphDescendants distinct keys.
  ///
  /// The returned widget is intended for the associated flight. Do not retain
  /// this endpoint context to register widgets after
  /// [MorphFlightDelegate.properties] returns.
  ///
  /// See the [Morph guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph.md#register-descendant-content)
  /// for an example.
  @useResult
  Widget descendantWidget(Widget child) {
    return _descendantCapture.register(child);
  }

  /// Prepares a group's combined snapshot for this endpoint's flight.
  ///
  /// Call synchronously from [MorphFlightDelegate.properties] and build the
  /// returned widget in that flight. Members may live outside the Morph subtree.
  /// The endpoint rectangle defines the snapshot's bounds and scale origin.
  /// Morph manages capture, original visibility, and disposal automatically.
  Widget groupSnapshot(GroupLink link) {
    return _descendantCapture.registerGroup(link, this);
  }

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
