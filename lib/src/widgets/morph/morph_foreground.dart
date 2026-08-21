part of 'morph.dart';

/// Keeps [child] visible above Morph transitions.
///
/// Use this for controls and other foreground content that should keep its
/// current layout position while a nearby [Morph] moves underneath it. Its live visual
/// state remains visible without becoming part of the Morph transition, and it
/// remains non-interactive until the transition finishes.
///
/// Without an enclosing [Overlay], this widget renders [child] normally.
///
/// See the [MorphForeground guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph_foreground.md)
/// for usage and constraints.
class MorphForeground extends StatefulWidget {
  /// Creates content that remains visible above Morph transitions.
  const MorphForeground({required this.child, super.key});

  /// Content displayed normally at rest and above active Morph transitions.
  final Widget child;

  @override
  State<MorphForeground> createState() => _MorphForegroundState();
}

class _MorphForegroundState extends State<MorphForeground> {
  final _MorphVisibilityHandle _visibility = _MorphVisibilityHandle();
  late final VoidCallback _onGeometryChanged;
  late final ValueChanged<_RenderMorphForegroundBoundary> _onRenderObjectReady;
  _MorphForegroundHandle? _handle;
  _RenderMorphForegroundBoundary? _renderObject;
  RenderBox? _overlayRenderObject;

  static void _ignoreEndpointRenderObject(_RenderMorphEndpoint renderObject) {}

  static void _ignoreEndpointPaint() {}

  void _handleGeometryChanged() => _handle?.changed();

  void _handleRenderObjectReady(
    _RenderMorphForegroundBoundary renderObject,
  ) {
    final handle = _handle;
    if (handle == null) {
      _renderObject = renderObject;
      return;
    }
    handle.renderObjectChanged(_renderObject, renderObject);
  }

  @override
  void initState() {
    super.initState();
    _onGeometryChanged = _handleGeometryChanged;
    _onRenderObjectReady = _handleRenderObjectReady;
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
      return;
    }

    _detach();
    final coordinator = _MorphCoordinator.of(overlay);
    final handle = _MorphForegroundHandle(
      owner: this,
      visibility: _visibility,
      coordinator: coordinator,
      route: route,
    );
    _handle = handle;
    coordinator
      ..addListener(_handleCoordinatorChanged)
      ..registerForeground(handle);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_handle, handle)) return;
      final overlayRenderObject = overlay.context.findRenderObject();
      if (overlayRenderObject is! RenderBox) return;
      _overlayRenderObject = overlayRenderObject;
      handle.invalidateTransformPath();
      coordinator.foregroundGeometryChanged(handle);
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
        ..unregisterForeground(handle);
    }
    _handle = null;
    _overlayRenderObject = null;
    _visibility.hidden = false;
  }

  void _handleCoordinatorChanged() {
    final handle = _handle;
    if (handle == null) return;
    _visibility.hidden = handle.coordinator.showsForeground(handle);
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
  void deactivate() {
    final handle = _handle;
    if (handle != null) {
      handle.invalidateTransformPath();
      handle.coordinator.deactivateForeground(handle);
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    final handle = _handle;
    if (handle != null) {
      handle.invalidateTransformPath();
      handle.coordinator.activateForeground(handle);
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
    return _MorphEndpointBoundary(
      visibility: _visibility,
      onRenderObjectReady: _ignoreEndpointRenderObject,
      onPaint: _ignoreEndpointPaint,
      onPresented: _ignoreEndpointPaint,
      child: _MorphForegroundBoundary(
        handle: _handle,
        onGeometryChanged: _onGeometryChanged,
        onRenderObjectReady: _onRenderObjectReady,
        child: widget.child,
      ),
    );
  }
}
