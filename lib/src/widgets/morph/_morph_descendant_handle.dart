part of 'morph.dart';

final class _MorphDescendantHandle {
  _MorphDescendantHandle({required this.owner});

  final _MorphDescendantState owner;
  _RenderMorphDescendant? _renderObject;
  int registrationOrder = 0;
  int snapshotRevision = 0;
  bool _snapshotDirty = true;

  void attachRenderObject(_RenderMorphDescendant value) {
    if (!identical(value, _renderObject)) {
      _renderObject = value;
    }
    markSnapshotDirty();
  }

  _RenderMorphDescendant? get capturableRenderObject {
    final renderObject = _renderObject;
    if (renderObject == null || !renderObject.attached || !renderObject.hasSize) {
      return null;
    }
    return renderObject;
  }

  bool get snapshotDirty => _snapshotDirty;

  void markSnapshotDirty() {
    snapshotRevision += 1;
    if (_snapshotDirty) return;
    _snapshotDirty = true;
    owner._endpoint?._descendantChanged(this);
  }

  void acceptSnapshotRevision(int revision) {
    if (snapshotRevision == revision) _snapshotDirty = false;
  }

  void dispose() {
    _renderObject = null;
  }

  _MorphDescendantFlightRecord capture(
    _RenderMorphDescendant renderObject, {
    _MorphContentSnapshot? snapshot,
    bool snapshotCaptureCompleted = false,
    bool? capturesContinuously,
  }) {
    final widget = owner.widget;
    final behavior = widget.flightBehavior;
    final size = renderObject.size;
    return _MorphDescendantFlightRecord(
      handle: this,
      registrationOrder: registrationOrder,
      key: widget.key,
      childType: widget.child.runtimeType,
      behavior: behavior,
      size: size,
      snapshotRevision: snapshotRevision,
      capturesContinuously:
          !size.isEmpty && (capturesContinuously ?? (behavior.usesSnapshot && renderObject.hasNestedRepaintBoundary)),
      snapshotCaptureCompleted: snapshotCaptureCompleted,
      snapshot: snapshot,
    );
  }
}
