part of 'group.dart';

class _RenderGroup extends RenderProxyBox {
  _RenderGroup(this._link, this._zIndex);

  GroupLink _link;
  double _zIndex;
  int _hiddenReferences = 0;
  int _revision = 0;

  @override
  void markNeedsPaint() {
    if (_link._captureDepth == 0) _revision++;
    super.markNeedsPaint();
  }

  void restoreAfterCapture() => super.markNeedsPaint();

  GroupLink get link => _link;
  set link(GroupLink value) {
    if (identical(value, _link)) return;
    if (attached) _link._detach(this);
    _link = value;
    if (attached) _link._attach(this);
    markNeedsPaint();
  }

  double get zIndex => _zIndex;
  set zIndex(double value) {
    if (_zIndex == value) return;
    _zIndex = value;
    markNeedsPaint();
  }

  bool get _hidden => _hiddenReferences > 0 && _link._captureDepth == 0;

  void _changeVisibility(int delta) {
    _hiddenReferences += delta;
    assert(_hiddenReferences >= 0, 'Group presentation releases must match acquisitions.');
    if (!attached) return;
    super.markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _link._attach(this);
  }

  @override
  void detach() {
    _link._detach(this);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hidden) super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      !_hidden && super.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (!_hidden) super.visitChildrenForSemantics(visitor);
  }
}
