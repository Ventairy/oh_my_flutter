part of 'resting_surface.dart';

class RenderRestingSurface extends RenderProxyBox implements MaybeSafeAreaTransform {
  new({required this._translation, required this._useRestingGeometry, required this._restingTranslation});

  Offset _translation;
  Offset get translation => _translation;
  set translation(Offset value) {
    if (value == _translation) return;
    _translation = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  Offset _restingTranslation;
  Offset get restingTranslation => _restingTranslation;
  set restingTranslation(Offset value) {
    if (value == _restingTranslation) return;
    _restingTranslation = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  bool _useRestingGeometry;
  bool get useRestingGeometry => _useRestingGeometry;
  set useRestingGeometry(bool value) {
    if (value == _useRestingGeometry) return;
    _useRestingGeometry = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  bool get usesRestingSafeAreaGeometry => _useRestingGeometry;

  @override
  void applyRestingPaintTransform(RenderObject child, Matrix4 transform) =>
      transform.translateByDouble(_restingTranslation.dx, _restingTranslation.dy, 0, 1);

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.translateByDouble(
    _translation.dx + _restingTranslation.dx,
    _translation.dy + _restingTranslation.dy,
    0,
    1,
  );

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.translationValues(_translation.dx + _restingTranslation.dx, _translation.dy + _restingTranslation.dy, 0),
      super.paint,
      oldLayer: layer as TransformLayer?,
    );
  }
}
