part of 'interactive_swipe_dismiss.dart';

class _RenderInteractiveSwipeDismissTranslation extends RenderProxyBox {
  _RenderInteractiveSwipeDismissTranslation(
    _InteractiveSwipeDismissTranslationController controller,
  ) : _controller = controller,
      _dx = controller.dx,
      _dy = controller.dy {
    controller.attach(this);
  }

  _InteractiveSwipeDismissTranslationController _controller;
  double _dx;
  double _dy;

  void updateController(
    _InteractiveSwipeDismissTranslationController value,
  ) {
    if (identical(_controller, value)) return;
    _controller.detach(this);
    _controller = value;
    _controller.attach(this);
  }

  void setTranslation(double dx, double dy) {
    if (_dx == dx && _dy == dy) return;
    _dx = dx;
    _dy = dy;
    markNeedsCompositedLayerUpdate();
    if (owner?.semanticsOwner != null) markNeedsSemanticsUpdate();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  OffsetLayer updateCompositedLayer({
    required covariant _InteractiveSwipeDismissTranslationLayer? oldLayer,
  }) {
    return (oldLayer ?? _InteractiveSwipeDismissTranslationLayer())..setTranslation(_dx, _dy);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintOffset(
      offset: Offset(_dx, _dy),
      position: position,
      hitTest: (result, transformed) {
        return super.hitTestChildren(result, position: transformed);
      },
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_dx, _dy, 0, 1);
  }

  @override
  void dispose() {
    _controller.detach(this);
    super.dispose();
  }
}
