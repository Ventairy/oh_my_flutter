part of 'morph.dart';

/// Coordinates [child] with a matching Morph transition outside its subtree.
///
/// Use this for controls and other widgets that sit beside a [Morph] and need
/// to respond to its transition without becoming matched content.
///
/// A [transitionBuilder] can use the matching Morph's visual progress to
/// animate the sibling independently. When [paintAboveMorph] is enabled, its
/// live visual is also painted immediately above the matching flight.
///
/// See the [MorphSibling guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph_sibling.md)
/// for usage and constraints.
class MorphSibling extends StatefulWidget {
  /// Creates content coordinated with the Morph identified by [tag].
  const MorphSibling({
    required this.tag,
    required this.child,
    this.paintAboveMorph = true,
    this.transitionBuilder,
    super.key,
  });

  /// Identifies the [Morph] whose flight this sibling accompanies.
  final Object tag;

  /// Content coordinated with the matching Morph flight.
  final Widget child;

  /// Whether the sibling paints immediately above its matching Morph flight.
  ///
  /// Later flights with other tags remain above this sibling. When false, the
  /// sibling stays in its normal widget-tree paint order while still receiving
  /// the matching animation through [transitionBuilder].
  final bool paintAboveMorph;

  /// Builds the sibling's visual response to the matching Morph flight.
  ///
  /// The animation uses the matching Morph's curved visual progress, clamped
  /// from 0 to 1. It advances as this sibling's route appears, reverses as the
  /// route departs, and remains at 1 while no matching flight is active.
  ///
  /// When omitted, [child] remains visually unchanged during the flight.
  final Widget Function(
    Widget child,
    Animation<double> animation,
  )?
  transitionBuilder;

  @override
  State<MorphSibling> createState() => _MorphSiblingState();
}

class _MorphSiblingState extends State<MorphSibling> {
  final _MorphVisibilityHandle _visibility = _MorphVisibilityHandle();
  final ProxyAnimation _transitionAnimation = ProxyAnimation(
    kAlwaysCompleteAnimation,
  );
  late final VoidCallback _onGeometryChanged;
  late final ValueChanged<_RenderMorphSiblingBoundary> _onRenderObjectReady;
  _MorphSiblingHandle? _handle;
  _RenderMorphSiblingBoundary? _renderObject;
  RenderBox? _overlayRenderObject;

  static void _ignoreEndpointRenderObject(_RenderMorphEndpoint renderObject) {}

  static void _ignoreEndpointPaint() {}

  void _handleGeometryChanged() => _handle?.changed();

  void _handleRenderObjectReady(
    _RenderMorphSiblingBoundary renderObject,
  ) {
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

    final route = ModalRoute.of(context);
    final current = _handle;
    if (current != null && identical(current.overlay, overlay) && identical(current.route, route)) {
      if (current.tag == widget.tag) return;
    }

    _detach();
    final coordinator = _MorphCoordinator.of(overlay);
    final handle = _MorphSiblingHandle(
      owner: this,
      visibility: _visibility,
      coordinator: coordinator,
      route: route,
      tag: widget.tag,
      transitionAnimation: _transitionAnimation,
    );
    _handle = handle;
    coordinator
      ..addListener(_handleCoordinatorChanged)
      ..registerSibling(handle);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_handle, handle)) return;
      final overlayRenderObject = overlay.context.findRenderObject();
      if (overlayRenderObject is! RenderBox) return;
      _overlayRenderObject = overlayRenderObject;
      handle.invalidateTransformPath();
      coordinator.siblingGeometryChanged(handle);
    });
  }

  void _detach() {
    final handle = _handle;
    final renderObject = _renderObject;
    _renderObject = null;
    renderObject?.projected = false;
    if (handle != null) {
      handle.coordinator
        ..removeListener(_handleCoordinatorChanged)
        ..unregisterSibling(handle);
    }
    _handle = null;
    _overlayRenderObject = null;
    _visibility.hidden = false;
  }

  void _handleCoordinatorChanged() {
    final handle = _handle;
    if (handle == null) return;
    _visibility.hidden = handle.coordinator.showsSibling(handle);
  }

  @override
  void initState() {
    super.initState();
    _onGeometryChanged = _handleGeometryChanged;
    _onRenderObjectReady = _handleRenderObjectReady;
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
  void didUpdateWidget(covariant MorphSibling oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hadTransition = oldWidget.transitionBuilder != null;
    final hasTransition = widget.transitionBuilder != null;
    if (oldWidget.tag == widget.tag &&
        oldWidget.paintAboveMorph == widget.paintAboveMorph &&
        hadTransition == hasTransition) {
      return;
    }
    _detach();
    _attach();
  }

  @override
  void deactivate() {
    final handle = _handle;
    if (handle != null) {
      handle.invalidateTransformPath();
      handle.coordinator.deactivateSibling(handle);
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    final handle = _handle;
    if (handle != null) {
      handle.invalidateTransformPath();
      handle.coordinator.activateSibling(handle);
    }
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
    final transitionedChild = widget.transitionBuilder?.call(
      widget.child,
      _transitionAnimation,
    );
    return _MorphEndpointBoundary(
      visibility: _visibility,
      onRenderObjectReady: _ignoreEndpointRenderObject,
      onPaint: _ignoreEndpointPaint,
      onPresented: _ignoreEndpointPaint,
      child: _MorphSiblingBoundary(
        handle: _handle,
        onGeometryChanged: _onGeometryChanged,
        onRenderObjectReady: _onRenderObjectReady,
        child: transitionedChild ?? widget.child,
      ),
    );
  }
}
