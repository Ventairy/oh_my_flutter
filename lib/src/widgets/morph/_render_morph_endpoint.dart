part of 'morph.dart';

class _RenderMorphEndpoint extends RenderProxyBox {
  new(
    this._visibility,
    this.onPaint,
    this.onPresented,
    this.onSnapshotSuppressed,
  );

  _MorphVisibilityHandle _visibility;
  VoidCallback onPaint;
  VoidCallback onPresented;
  VoidCallback onSnapshotSuppressed;
  int _snapshotSuppressionDepth = 0;
  LayerHandle<OpacityLayer>? _hiddenOpacityLayer;

  void beginSnapshotSuppression() {
    _snapshotSuppressionDepth += 1;
    if (_snapshotSuppressionDepth == 1) {
      onSnapshotSuppressed();
      markNeedsPaint();
    }
  }

  void endSnapshotSuppression() {
    assert(
      _snapshotSuppressionDepth > 0,
      'A Morph endpoint snapshot suppression must begin before it can end.',
    );
    _snapshotSuppressionDepth -= 1;
    if (_snapshotSuppressionDepth == 0) markNeedsPaint();
  }

  _MorphVisibilityHandle get visibility => _visibility;

  set visibility(_MorphVisibilityHandle value) {
    if (identical(value, _visibility)) return;
    if (attached) _visibility.removeListener(_handleVisibilityChanged);
    _visibility = value;
    if (attached) _visibility.addListener(_handleVisibilityChanged);
    _handleVisibilityChanged();
  }

  void _handleVisibilityChanged() {
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _visibility.addListener(_handleVisibilityChanged);
  }

  @override
  void detach() {
    _visibility.removeListener(_handleVisibilityChanged);
    super.detach();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_visibility.hidden) return false;
    return super.hitTest(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_snapshotSuppressionDepth > 0 || (_visibility.hidden && !_visibility.paintsWhileHidden)) {
      _clearHiddenOpacityLayer();
      return;
    }
    if (_visibility.hidden) {
      final hiddenOpacityLayer = _hiddenOpacityLayer ??= LayerHandle<OpacityLayer>();
      hiddenOpacityLayer.layer = _visibility.paintHiddenGroups(
        () => context.pushOpacity(
          offset,
          0,
          super.paint,
          oldLayer: hiddenOpacityLayer.layer,
        ),
      );
      return;
    }
    _clearHiddenOpacityLayer();
    _paintEndpoint(context, offset);
    if (_visibility.tickersEnabled.value) onPresented();
  }

  void _paintEndpoint(PaintingContext context, Offset offset) {
    // An ancestor can change this endpoint's paint transform without laying
    // it out. Sampling only on an actual visible paint preserves the last
    // geometry shown to the user while retained, unpainted subtrees do no work.
    onPaint();
    super.paint(context, offset);
  }

  void _clearHiddenOpacityLayer() {
    _hiddenOpacityLayer?.layer = null;
    _hiddenOpacityLayer = null;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_visibility.hidden) return;
    super.visitChildrenForSemantics(visitor);
  }

  @override
  void dispose() {
    _clearHiddenOpacityLayer();
    super.dispose();
  }
}
