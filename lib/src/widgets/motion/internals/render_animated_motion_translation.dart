part of '../motion.dart';

class _RenderAnimatedMotionTranslation extends RenderProxyBox {
  _RenderAnimatedMotionTranslation({
    required this._animation,
    required this._begin,
    required this._end,
    required this._floatingDistance,
  }) {
    _updateTranslation();
  }

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
    _updateTranslation();
  }

  Offset get begin => _begin;
  Offset _begin;
  set begin(Offset value) {
    if (_begin == value) {
      return;
    }
    _begin = value;
    _updateTranslation();
  }

  Offset get end => _end;
  Offset _end;
  set end(Offset value) {
    if (_end == value) {
      return;
    }
    _end = value;
    _updateTranslation();
  }

  double? get floatingDistance => _floatingDistance;
  double? _floatingDistance;
  set floatingDistance(double? value) {
    if (_floatingDistance == value) {
      return;
    }
    _floatingDistance = value;
    _updateTranslation();
  }

  double _translationX = 0;
  double _translationY = 0;
  late final VoidCallback _animationListener = _updateTranslation;

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
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_translationX == 0 && _translationY == 0) {
      return super.hitTestChildren(result, position: position);
    }
    return result.addWithPaintOffset(
      offset: Offset(_translationX, _translationY),
      position: position,
      hitTest: (result, position) {
        return super.hitTestChildren(result, position: position);
      },
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      return;
    }
    if (_translationX == 0 && _translationY == 0) {
      super.paint(context, offset);
      return;
    }
    super.paint(
      context,
      Offset(offset.dx + _translationX, offset.dy + _translationY),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_translationX == 0 && _translationY == 0) {
      return;
    }
    transform.translateByDouble(_translationX, _translationY, 0, 1);
  }

  void _updateTranslation() {
    final progress = _animation.value;
    final distance = _floatingDistance;
    late final double translationX;
    late final double translationY;
    if (distance == null) {
      translationX = switch (progress) {
        0 => _begin.dx,
        1 => _end.dx,
        _ => _begin.dx + (_end.dx - _begin.dx) * progress,
      };
      translationY = switch (progress) {
        0 => _begin.dy,
        1 => _end.dy,
        _ => _begin.dy + (_end.dy - _begin.dy) * progress,
      };
    } else {
      translationX = 0;
      translationY = switch (progress) {
        0 || 0.5 || 1 => 0,
        < 0.5 => -16 * distance * progress * (0.5 - progress),
        _ => 16 * distance * (progress - 0.5) * (1 - progress),
      };
    }
    if (_translationX == translationX && _translationY == translationY) {
      return;
    }
    _translationX = translationX;
    _translationY = translationY;
    markNeedsPaint();
    if (owner?.semanticsOwner != null) {
      markNeedsSemanticsUpdate();
    }
  }
}
