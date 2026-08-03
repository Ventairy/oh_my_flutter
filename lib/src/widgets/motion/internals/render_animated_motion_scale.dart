part of '../motion.dart';

class _RenderAnimatedMotionScale extends RenderProxyBox {
  _RenderAnimatedMotionScale({
    required this._animation,
    required this._beginScale,
  }) {
    _updateScale();
  }

  final Matrix4 _transform = Matrix4.identity();

  Animation<double> get animation => _animation;
  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (identical(_animation, value)) {
      return;
    }
    if (attached) {
      _animation.removeListener(_animationListener);
    }
    _animation = value;
    if (attached) {
      _animation.addListener(_animationListener);
    }
    _updateScale();
  }

  double get beginScale => _beginScale;
  double _beginScale;
  set beginScale(double value) {
    if (_beginScale == value) {
      return;
    }
    _beginScale = value;
    _updateScale();
  }

  double _scale = 1;
  late final VoidCallback _animationListener = _updateScale;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addListener(_animationListener);
  }

  @override
  void detach() {
    _animation.removeListener(_animationListener);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    _updateTransform();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_scale == 0 || !_scale.isFinite) {
      return false;
    }
    if (_scale == 1) {
      return super.hitTestChildren(result, position: position);
    }
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) {
        return super.hitTestChildren(result, position: position);
      },
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || _scale == 0 || !_scale.isFinite) {
      layer = null;
      return;
    }
    if (_scale == 1) {
      super.paint(context, offset);
      layer = null;
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer as TransformLayer? : null,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }

  void _updateScale() {
    final progress = _animation.value;
    final scale = switch (progress) {
      0 => _beginScale,
      1 => 1.0,
      _ => _beginScale + (1 - _beginScale) * progress,
    };
    if (_scale == scale) {
      return;
    }
    _scale = scale;
    if (hasSize) {
      _updateTransform();
    }
    markNeedsPaint();
    if (owner?.semanticsOwner != null) {
      markNeedsSemanticsUpdate();
    }
  }

  void _updateTransform() {
    final storage = _transform.storage;
    storage[0] = _scale;
    storage[5] = _scale;
    storage[12] = (1 - _scale) * size.width / 2;
    storage[13] = (1 - _scale) * size.height / 2;
  }
}
