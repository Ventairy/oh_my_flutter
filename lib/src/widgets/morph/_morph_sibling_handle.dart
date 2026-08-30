part of 'morph.dart';

final class _MorphSiblingHandle {
  _MorphSiblingHandle({
    required this.owner,
    required this.visibility,
    required this.coordinator,
    required this.route,
    required this.tag,
    required this.transitionAnimation,
  });

  final _MorphSiblingState owner;
  final _MorphVisibilityHandle visibility;
  final _MorphCoordinator coordinator;
  final ModalRoute<Object?>? route;
  final Object tag;
  final ProxyAnimation transitionAnimation;
  final Matrix4 _transform = Matrix4.identity();
  late final VoidCallback _flightAnimationListener = changed;
  late final Widget overlayProjection = Positioned.fill(
    key: ObjectKey(this),
    child: ExcludeSemantics(
      child: _MorphSiblingPaint(handle: this),
    ),
  );
  Matrix4? _firstLayerTransform;
  Matrix4? _secondLayerTransform;
  List<RenderObject>? _transformPath;
  _MorphActiveFlight? _flight;
  Animation<double>? _flightAnimation;
  _RenderMorphSiblingPaint? _projection;
  bool active = true;
  bool disposed = false;
  bool _usesFirstLayerTransform = false;

  OverlayState get overlay => coordinator.overlay;

  bool get canPaint {
    final renderObject = owner._renderObject;
    final overlayRenderObject = owner._overlayRenderObject;
    return active &&
        !disposed &&
        renderObject != null &&
        renderObject.attached &&
        renderObject.hasSize &&
        overlayRenderObject != null &&
        overlayRenderObject.attached &&
        overlayRenderObject.hasSize;
  }

  bool get isProjected => _projection != null;

  bool get hasTransition => owner.widget.transitionBuilder != null;

  bool get paintsAboveMorph => owner.widget.paintAboveMorph;

  void changed() {
    if (!disposed) _projection?.markTransformNeedsUpdate();
  }

  void sourceChanged() {
    if (!disposed) _projection?.markSourceNeedsUpdate();
  }

  void attachProjection(_RenderMorphSiblingPaint projection) {
    assert(
      _projection == null || identical(_projection, projection),
      'A MorphSibling can only have one live overlay projection.',
    );
    _projection = projection;
    owner._renderObject?.projected = true;
  }

  void attachFlight(
    _MorphActiveFlight flight,
    Animation<double> animation,
  ) {
    if (identical(_flight, flight) && identical(_flightAnimation, animation)) {
      return;
    }
    _flightAnimation?.removeListener(_flightAnimationListener);
    _flight = flight;
    _flightAnimation = animation;
    animation.addListener(_flightAnimationListener);
    transitionAnimation.parent = _MorphSiblingClampedAnimation(
      animation,
    );
    changed();
  }

  void detachFlight(_MorphActiveFlight flight) {
    if (!identical(_flight, flight)) return;
    _flightAnimation?.removeListener(_flightAnimationListener);
    _flight = null;
    _flightAnimation = null;
    transitionAnimation.parent = kAlwaysCompleteAnimation;
    changed();
  }

  void prepareForIncomingFlight() {
    if (_flight != null || !hasTransition) return;
    transitionAnimation.parent = kAlwaysDismissedAnimation;
  }

  void resetFlight() {
    _flightAnimation?.removeListener(_flightAnimationListener);
    _flight = null;
    _flightAnimation = null;
  }

  void settleTransition() {
    if (identical(transitionAnimation.parent, kAlwaysCompleteAnimation)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (disposed || _flight != null) return;
      transitionAnimation.parent = kAlwaysCompleteAnimation;
    });
  }

  void detachProjection(_RenderMorphSiblingPaint projection) {
    if (!identical(_projection, projection)) return;
    _projection = null;
    owner._renderObject?.projected = false;
  }

  void renderObjectChanged(
    _RenderMorphSiblingBoundary? previous,
    _RenderMorphSiblingBoundary current,
  ) {
    if (identical(previous, current)) return;
    previous?.projected = false;
    owner._renderObject = current;
    current.projected = isProjected;
    invalidateTransformPath();
    sourceChanged();
  }

  void renderObjectDisposed(_RenderMorphSiblingBoundary renderObject) {
    if (identical(owner._renderObject, renderObject)) {
      owner._renderObject = null;
    }
  }

  void invalidateTransformPath() {
    _transformPath?.clear();
  }

  Matrix4? resolveTransform() {
    if (!active || disposed) return null;
    final source = owner._renderObject;
    final target = owner._overlayRenderObject;
    if (source == null ||
        !source.attached ||
        !source.hasSize ||
        target == null ||
        !target.attached ||
        !target.hasSize) {
      return null;
    }

    var path = _transformPath;
    if (path == null || path.isEmpty || !identical(path.first, source) || !identical(path.last, target)) {
      path = _rebuildTransformPath(source, target);
      if (path == null) return null;
    }
    _transform.setIdentity();
    if (_applyTransformPath(path)) return _transform;

    path = _rebuildTransformPath(source, target);
    if (path == null) return null;
    _transform.setIdentity();
    if (!_applyTransformPath(path)) {
      path.clear();
      return null;
    }
    return _transform;
  }

  Matrix4 copyLayerTransform(Matrix4 transform) {
    _usesFirstLayerTransform = !_usesFirstLayerTransform;
    final layerTransform = _usesFirstLayerTransform
        ? (_firstLayerTransform ??= Matrix4.identity())
        : (_secondLayerTransform ??= Matrix4.identity());
    return layerTransform..setFrom(transform);
  }

  List<RenderObject>? _rebuildTransformPath(
    RenderObject source,
    RenderObject target,
  ) {
    final path = (_transformPath ?? <RenderObject>[])..clear();
    RenderObject? node = source;
    while (node != null) {
      path.add(node);
      if (identical(node, target)) break;
      node = node.parent;
    }
    if (path.isEmpty || !identical(path.last, target)) {
      _transformPath = path;
      return null;
    }
    _transformPath = path;
    return path;
  }

  bool _applyTransformPath(List<RenderObject> path) {
    for (var index = path.length - 1; index > 0; index -= 1) {
      final parent = path[index];
      final child = path[index - 1];
      if (!identical(child.parent, parent)) return false;
      parent.applyPaintTransform(child, _transform);
    }
    return true;
  }

  void dispose() {
    if (disposed) return;
    disposed = true;
    resetFlight();
    _transformPath?.clear();
    _transformPath = null;
    _firstLayerTransform = null;
    _secondLayerTransform = null;
    _projection = null;
  }
}
