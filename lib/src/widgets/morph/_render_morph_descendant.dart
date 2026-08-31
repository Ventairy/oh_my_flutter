part of 'morph.dart';

class _RenderMorphDescendant extends RenderProxyBox {
  _RenderMorphDescendant(this._onVisualChange);

  final void Function(_RenderMorphDescendant renderObject) _onVisualChange;
  int _snapshotCaptureDepth = 0;

  @override
  void performLayout() {
    final previousSize = hasSize ? size : null;
    super.performLayout();
    if (size != previousSize) _reportVisualChange();
  }

  @override
  void markNeedsPaint() {
    _reportVisualChange();
    super.markNeedsPaint();
  }

  bool get hasNestedRepaintBoundary {
    var result = false;
    void visit(RenderObject child) {
      if (child is _RenderMorphEndpoint) return;
      if (child.isRepaintBoundary) {
        result = true;
        return;
      }
      child.visitChildren(visit);
    }

    visitChildren(visit);
    return result;
  }

  void beginSnapshotCapture() => _snapshotCaptureDepth += 1;

  void endSnapshotCapture() {
    assert(
      _snapshotCaptureDepth > 0,
      'A Morph snapshot capture must begin before it can end.',
    );
    _snapshotCaptureDepth -= 1;
    if (_snapshotCaptureDepth == 0 && needsCompositing) {
      // Offscreen painting can temporarily reparent descendant layers into the
      // snapshot layer tree. Repaint the resting subtree without treating that
      // restoration as a new visual change.
      super.markNeedsPaint();
    }
  }

  void _reportVisualChange() {
    if (_snapshotCaptureDepth == 0) _onVisualChange(this);
  }
}
