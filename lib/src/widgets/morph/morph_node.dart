part of 'morph.dart';

/// Configures how a child widget participates in a [MorphTarget] flight.
///
/// Share [target] with the moving [Morph]. During a matching flight, [child]
/// paints in Morph's overlay at its layout position. [transitionBuilder]
/// configures its projected visual, and [zIndex] sets its paint order relative
/// to the moving Morph. The child stays live while its widget remains mounted.
///
/// See the [Morph guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph.md)
/// for an example.
class MorphNode extends StatefulWidget {
  /// Configures [child] for flights associated with [target].
  const new({
    required this.target,
    required this.child,
    this.zIndex = -1,
    this.transitionBuilder,
    super.key,
  }) : assert(zIndex != 0, 'Use a negative or positive zIndex to place the node around its flight.');

  /// The same target instance used by the matching [Morph].
  final MorphTarget target;

  /// Content that remains laid out at this widget's position.
  final Widget child;

  /// Paint order relative to the matching flight: negative behind, positive above.
  ///
  /// Nodes at the same depth keep their registration order. Other flights
  /// retain their existing order in Morph's overlay.
  final double zIndex;

  /// Wraps the projected visual while a flight is active.
  ///
  /// The animations run from the flight's source (0) to destination (1).
  /// The curved animation follows the target curve; the uncurved animation follows
  /// the flight clock. The original [child] is not wrapped by this builder.
  /// Use it for effects such as a route fade on the projected visual.
  final Widget Function(
    BuildContext context,
    Widget child,
    Animation<double> curvedAnimation,
    Animation<double> uncurvedAnimation,
  )?
  transitionBuilder;

  @override
  State<MorphNode> createState() => _MorphNodeState();
}

class _MorphNodeState extends State<MorphNode> {
  final _MorphVisibilityHandle _visibility = _MorphVisibilityHandle();
  final LayerLink _layerLink = LayerLink();
  _MorphNodeHandle? _handle;
  _RenderMorphNodeBoundary? _renderObject;

  void _handleRenderObjectReady(_RenderMorphNodeBoundary renderObject) {
    final handle = _handle;
    if (handle == null) {
      _renderObject = renderObject;
      return;
    }
    handle.renderObjectChanged(_renderObject, renderObject);
  }

  void _attach() {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      _detach();
      return;
    }
    final current = _handle;
    if (current != null && identical(current.overlay, overlay) && identical(current.target, widget.target)) return;

    _detach();
    final coordinator = _MorphCoordinator.of(overlay);
    final handle = _MorphNodeHandle(owner: this, coordinator: coordinator, target: widget.target);
    _handle = handle;
    coordinator
      ..addListener(_handleCoordinatorChanged)
      ..registerNode(handle);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_handle, handle)) coordinator.nodeGeometryChanged(handle);
    });
  }

  void _detach() {
    final handle = _handle;
    _renderObject?.projected = false;
    _renderObject = null;
    if (handle != null) {
      handle.coordinator
        ..removeListener(_handleCoordinatorChanged)
        ..unregisterNode(handle);
    }
    _handle = null;
    _visibility.hidden = false;
  }

  void _handleCoordinatorChanged() {
    final handle = _handle;
    if (handle == null) return;
    _visibility.hidden = handle.coordinator.showsNode(handle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_MorphFlightScope.contains(context)) {
      _detach();
      return;
    }
    _attach();
  }

  @override
  void didUpdateWidget(covariant MorphNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.target, widget.target)) {
      _detach();
      _attach();
      return;
    }
    if (oldWidget.zIndex != widget.zIndex || oldWidget.transitionBuilder != widget.transitionBuilder) {
      _handle?.coordinator.nodeGeometryChanged(_handle!);
    }
  }

  @override
  void deactivate() {
    final handle = _handle;
    if (handle != null) handle.coordinator.deactivateNode(handle);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    final handle = _handle;
    if (handle != null) handle.coordinator.activateNode(handle);
  }

  @override
  void dispose() {
    _detach();
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_MorphFlightScope.contains(context)) return widget.child;
    return CompositedTransformTarget(
      link: _layerLink,
      child: _MorphEndpointBoundary(
        visibility: _visibility,
        onRenderObjectReady: (_) {},
        onPaint: () {},
        onPresented: () {},
        onSnapshotSuppressed: () {},
        child: _MorphNodeBoundary(
          handle: _handle,
          onGeometryChanged: () => _handle?.changed(),
          onRenderObjectReady: _handleRenderObjectReady,
          child: widget.child,
        ),
      ),
    );
  }
}
