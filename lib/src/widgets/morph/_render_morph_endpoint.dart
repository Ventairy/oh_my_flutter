part of 'morph.dart';

class _RenderMorphEndpoint extends RenderProxyBox {
  _RenderMorphEndpoint(
    this._visibility,
    this.onPaint,
    this.onPresented,
  );

  _MorphVisibilityHandle _visibility;
  VoidCallback onPaint;
  VoidCallback onPresented;
  bool _snapshotSuppressed = false;

  void _setSnapshotSuppressed(bool value) {
    if (value == _snapshotSuppressed) return;
    _snapshotSuppressed = value;
    markNeedsPaint();
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
    if (_visibility.hidden || _snapshotSuppressed) return;
    // An ancestor can change this endpoint's paint transform without laying
    // it out. Sampling only on an actual visible paint preserves the last
    // geometry shown to the user while retained, unpainted subtrees do no work.
    onPaint();
    super.paint(context, offset);
    if (_visibility.tickersEnabled.value) onPresented();
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_visibility.hidden) return;
    super.visitChildrenForSemantics(visitor);
  }
}
