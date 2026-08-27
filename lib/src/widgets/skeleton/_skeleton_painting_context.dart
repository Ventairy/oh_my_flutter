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

  static bool _isLeaf(RenderObject child) {
    var hasChild = false;
    child.visitChildren((_) => hasChild = true);
    return !hasChild;
  }

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
    if (child.isRepaintBoundary) {
      (canvas as _SkeletonCanvas).recordBoundsBone(
        child.paintBounds.shift(offset),
      );
      return;
    }

    if (!_isLeaf(child)) {
      super.paintChild(child, offset);
      return;
    }

    final wasPaintingLeaf = _paintState.isPaintingLeaf;
    final previousBounds = _paintState.leafBounds;
    final previousFallbackRecorded = _paintState.leafFallbackRecorded;
    _paintState
      ..isPaintingLeaf = true
      ..leafBounds = child.paintBounds.shift(offset)
      ..leafFallbackRecorded = false;
    try {
      super.paintChild(child, offset);
    } finally {
      _paintState
        ..isPaintingLeaf = wasPaintingLeaf
        ..leafBounds = previousBounds
        ..leafFallbackRecorded = previousFallbackRecorded;
    }
  }

  @override
  void pushLayer(
    ContainerLayer childLayer,
    PaintingContextCallback painter,
    Offset offset, {
    Rect? childPaintBounds,
  }) {
    if (_paintState.isPaintingLeaf) {
      childLayer
        ..removeAllChildren()
        ..remove();
      (canvas as _SkeletonCanvas).recordLeafFallbackBone();
      return;
    }
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
    if (_paintState.isPaintingLeaf) {
      layer.remove();
      (canvas as _SkeletonCanvas).recordLeafFallbackBone();
      return;
    }
    super.appendLayer(layer);
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
