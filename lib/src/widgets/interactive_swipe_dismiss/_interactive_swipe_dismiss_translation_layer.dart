part of 'interactive_swipe_dismiss.dart';

class _InteractiveSwipeDismissTranslationLayer extends OffsetLayer {
  double _dx = 0;
  double _dy = 0;

  void setTranslation(double dx, double dy) {
    if (_dx == dx && _dy == dy) return;
    _dx = dx;
    _dy = dy;
    markNeedsAddToScene();
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    engineLayer = builder.pushOffset(
      offset.dx + _dx,
      offset.dy + _dy,
      oldLayer: engineLayer as ui.OffsetEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  bool findAnnotations<S extends Object>(
    AnnotationResult<S> result,
    Offset localPosition, {
    required bool onlyFirst,
  }) {
    return super.findAnnotations<S>(
      result,
      Offset(localPosition.dx - _dx, localPosition.dy - _dy),
      onlyFirst: onlyFirst,
    );
  }

  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    assert(
      child != null,
      'A translation layer can only transform one of its children.',
    );
    transform.translateByDouble(
      offset.dx + _dx,
      offset.dy + _dy,
      0,
      1,
    );
  }
}
