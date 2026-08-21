part of 'morph.dart';

final class _MorphForegroundHandle {
  _MorphForegroundHandle({
    required this.owner,
    required this.visibility,
    required this.coordinator,
    required this.route,
  });

  final _MorphForegroundState owner;
  final _MorphVisibilityHandle visibility;
  final _MorphCoordinator coordinator;
  final ModalRoute<Object?>? route;
  final Matrix4 _transform = Matrix4.identity();
  late final VoidCallback _flightAnimationListener = changed;
  late final Widget overlayProjection = Positioned.fill(
    key: ObjectKey(this),
    child: ExcludeSemantics(
      child: _MorphForegroundPaint(handle: this),
    ),
  );
  Matrix4? _firstLayerTransform;
  Matrix4? _secondLayerTransform;
  List<RenderObject>? _transformPath;
  Animation<double>? _primaryFlightAnimation;
  int _primaryFlightAnimationRetainCount = 0;
  Map<Animation<double>, int>? _additionalFlightAnimations;
  _RenderMorphForegroundPaint? _projection;
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

  void changed() {
    if (!disposed) _projection?.markTransformNeedsUpdate();
  }

  void sourceChanged() {
    if (!disposed) _projection?.markSourceNeedsUpdate();
  }

  void attachProjection(_RenderMorphForegroundPaint projection) {
    assert(
      _projection == null || identical(_projection, projection),
      'A MorphForeground can only have one live overlay projection.',
    );
    _projection = projection;
    owner._renderObject?.projected = true;
  }

  bool get isProjected => _projection != null;

  void attachFlightAnimation(Animation<double> animation) {
    if (identical(_primaryFlightAnimation, animation)) {
      _primaryFlightAnimationRetainCount += 1;
      return;
    }
    final additionalAnimations = _additionalFlightAnimations;
    final additionalRetainCount = additionalAnimations?[animation];
    if (additionalRetainCount != null) {
      additionalAnimations![animation] = additionalRetainCount + 1;
      return;
    }
    if (_primaryFlightAnimation == null) {
      _primaryFlightAnimation = animation;
      _primaryFlightAnimationRetainCount = 1;
    } else {
      (_additionalFlightAnimations ??= Map<Animation<double>, int>.identity())[animation] = 1;
    }
    animation.addListener(_flightAnimationListener);
  }

  void detachFlightAnimation(Animation<double> animation) {
    if (identical(_primaryFlightAnimation, animation)) {
      if (_primaryFlightAnimationRetainCount > 1) {
        _primaryFlightAnimationRetainCount -= 1;
        return;
      }
      animation.removeListener(_flightAnimationListener);
      _primaryFlightAnimation = null;
      _primaryFlightAnimationRetainCount = 0;
      return;
    }
    final animations = _additionalFlightAnimations;
    final retainCount = animations?[animation];
    if (retainCount == null) return;
    if (retainCount > 1) {
      animations![animation] = retainCount - 1;
      return;
    }
    animation.removeListener(_flightAnimationListener);
    animations!.remove(animation);
  }

  void detachAllFlightAnimations() {
    final primaryAnimation = _primaryFlightAnimation;
    if (primaryAnimation != null) {
      primaryAnimation.removeListener(_flightAnimationListener);
      _primaryFlightAnimation = null;
      _primaryFlightAnimationRetainCount = 0;
    }
    final additionalAnimations = _additionalFlightAnimations;
    if (additionalAnimations != null) {
      for (final animation in additionalAnimations.keys) {
        animation.removeListener(_flightAnimationListener);
      }
      additionalAnimations.clear();
    }
  }

  void detachProjection(_RenderMorphForegroundPaint projection) {
    if (!identical(_projection, projection)) return;
    _projection = null;
    owner._renderObject?.projected = false;
  }

  void renderObjectChanged(
    _RenderMorphForegroundBoundary? previous,
    _RenderMorphForegroundBoundary current,
  ) {
    if (identical(previous, current)) return;
    previous?.projected = false;
    owner._renderObject = current;
    current.projected = isProjected;
    invalidateTransformPath();
    sourceChanged();
  }

  void renderObjectDisposed(_RenderMorphForegroundBoundary renderObject) {
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
    detachAllFlightAnimations();
    _additionalFlightAnimations = null;
    _transformPath?.clear();
    _transformPath = null;
    _firstLayerTransform = null;
    _secondLayerTransform = null;
    _projection = null;
  }
}
