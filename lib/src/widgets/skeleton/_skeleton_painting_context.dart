part of 'skeleton.dart';

class _SkeletonPaintingContext extends PaintingContext {
  // Both values are retained locally, so neither positional argument can be a
  // super parameter without duplicating the container-layer reference.
  // ignore: use_super_parameters
  _SkeletonPaintingContext(
    ContainerLayer containerLayer,
    Rect estimatedBounds,
    this._paintState,
    this._segments,
    this._skeletonPaint,
    this._style,
    this._radius,
  ) : _containerLayer = containerLayer,
      super(containerLayer, estimatedBounds);

  final ContainerLayer _containerLayer;
  final _SkeletonPaintState _paintState;
  final List<_SkeletonBoneSegment> _segments;
  final Paint _skeletonPaint;
  final SkeletonStyle _style;
  final Radius _radius;

  _SkeletonCanvas? _skeletonCanvas;
  _SkeletonBoneSegment? _activeSegment;

  void finish() => stopRecordingIfNeeded();

  @override
  Canvas get canvas {
    final existingCanvas = _skeletonCanvas;
    if (existingCanvas != null) return existingCanvas;

    final segment = _SkeletonBoneSegment(bounds: estimatedBounds);
    _activeSegment = segment;
    return _skeletonCanvas = _SkeletonCanvas(
      parent: super.canvas,
      commands: segment.commands,
      paintState: _paintState,
      radius: _radius,
    );
  }

  @override
  void paintChild(RenderObject child, Offset offset) {
    final parentScope = _paintState.activeScope;
    if (parentScope?.capturesOwnPaint ?? false) return;

    if (child is _RenderSkeletonDescendant && !(parentScope?.ignoreAnnotations ?? false)) {
      _paintAnnotatedChild(child, offset, parentScope);
      return;
    }

    _paintNode(
      child,
      offset,
      deferredPaintLevels: parentScope?.childDeferredPaintLevels ?? 0,
      ignoreAnnotations: parentScope?.ignoreAnnotations ?? false,
    );
  }

  void _paintAnnotatedChild(
    _RenderSkeletonDescendant child,
    Offset offset,
    _SkeletonPaintScope? parentScope,
  ) {
    switch (child.behavior) {
      case SkeletonDescendantBehavior.hide:
        return;
      case SkeletonDescendantBehavior.deferToChildren:
        _paintNode(
          child,
          offset,
          deferredPaintLevels: (parentScope?.childDeferredPaintLevels ?? 0) + 1,
          ignoreAnnotations: false,
        );
        return;
      case SkeletonDescendantBehavior.paintAsBone:
        final previousBoneCount = _paintState.boneCount;
        _paintNode(
          child,
          offset,
          deferredPaintLevels: 0,
          ignoreAnnotations: true,
        );
        if (_paintState.boneCount == previousBoneCount) {
          (canvas as _SkeletonCanvas).recordBoundsBone(
            child.paintBounds.shift(offset),
          );
          parentScope?.hasDescendantBone = true;
        }
        return;
    }
  }

  void _paintNode(
    RenderObject child,
    Offset offset, {
    required int deferredPaintLevels,
    required bool ignoreAnnotations,
  }) {
    final parentScope = _paintState.activeScope;
    final scope = _SkeletonPaintScope(
      bounds: child.paintBounds.shift(offset),
      deferredPaintLevels: deferredPaintLevels,
      ignoreAnnotations: ignoreAnnotations,
    );
    final previousBoneCount = _paintState.boneCount;
    _paintState.activeScope = scope;
    try {
      if (child.isRepaintBoundary && deferredPaintLevels == 0) {
        (canvas as _SkeletonCanvas).recordBoundsBone(scope.bounds);
        scope.capturesOwnPaint = true;
        return;
      }
      if (child.isRepaintBoundary) {
        child.paint(this, offset);
      } else {
        super.paintChild(child, offset);
      }
    } finally {
      _paintState.activeScope = parentScope;
      if (parentScope != null && _paintState.boneCount > previousBoneCount) {
        parentScope.hasDescendantBone = true;
      }
    }
  }

  @override
  void pushLayer(
    ContainerLayer childLayer,
    PaintingContextCallback painter,
    Offset offset, {
    Rect? childPaintBounds,
  }) {
    if (childLayer is ShaderMaskLayer || childLayer is BackdropFilterLayer || childLayer is ColorFilterLayer) {
      childLayer.removeAllChildren();
      painter(this, offset);
      return;
    }
    super.pushLayer(
      childLayer,
      painter,
      offset,
      childPaintBounds: childPaintBounds,
    );
  }

  @override
  ColorFilterLayer pushColorFilter(
    Offset offset,
    ColorFilter colorFilter,
    PaintingContextCallback painter, {
    ColorFilterLayer? oldLayer,
  }) {
    final layer = (oldLayer ?? ColorFilterLayer())
      ..removeAllChildren()
      ..colorFilter = colorFilter;
    painter(this, offset);
    return layer;
  }

  @override
  OpacityLayer pushOpacity(
    Offset offset,
    int alpha,
    PaintingContextCallback painter, {
    OpacityLayer? oldLayer,
  }) {
    final layer = (oldLayer ?? OpacityLayer())
      ..removeAllChildren()
      ..alpha = alpha
      ..offset = offset;
    painter(this, offset);
    return layer;
  }

  @override
  void appendLayer(Layer layer) {
    layer.remove();
    (canvas as _SkeletonCanvas).recordFallbackBone();
  }

  @override
  PaintingContext createChildContext(ContainerLayer childLayer, Rect bounds) {
    return _SkeletonPaintingContext(
      childLayer,
      bounds,
      _paintState,
      _segments,
      _skeletonPaint,
      _style,
      _radius,
    );
  }

  @override
  void stopRecordingIfNeeded() {
    final activeSegment = _activeSegment;
    super.stopRecordingIfNeeded();
    _skeletonCanvas = null;
    _activeSegment = null;

    if (activeSegment == null || !activeSegment.commands.hasBones) return;
    activeSegment.attachTo(_containerLayer, _skeletonPaint, _style);
    _segments.add(activeSegment);
  }
}
