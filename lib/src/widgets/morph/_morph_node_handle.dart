part of 'morph.dart';

final class _MorphNodeHandle {
  new({required this.owner, required this.coordinator, required this.target});

  final _MorphNodeState owner;
  final _MorphCoordinator coordinator;
  final MorphTarget target;
  _RenderMorphNodePaint? _projection;
  int registrationOrder = 0;
  bool active = true;
  bool disposed = false;

  OverlayState get overlay => coordinator.overlay;

  bool get canPaint {
    final source = owner._renderObject;
    return active && !disposed && source != null && source.attached && source.hasSize;
  }

  void changed() {
    if (!disposed) _projection?.markSourceNeedsUpdate();
  }

  void attachProjection(_RenderMorphNodePaint projection) {
    assert(_projection == null || identical(_projection, projection), 'A MorphNode can have one projection.');
    _projection = projection;
    owner._renderObject?.projected = true;
  }

  void detachProjection(_RenderMorphNodePaint projection) {
    if (!identical(_projection, projection)) return;
    _projection = null;
    owner._renderObject?.projected = false;
  }

  void renderObjectChanged(_RenderMorphNodeBoundary? previous, _RenderMorphNodeBoundary current) {
    if (identical(previous, current)) return;
    previous?.projected = false;
    owner._renderObject = current;
    current.projected = _projection != null;
    changed();
  }

  void renderObjectDisposed(_RenderMorphNodeBoundary renderObject) {
    if (identical(owner._renderObject, renderObject)) owner._renderObject = null;
  }

  void dispose() {
    if (disposed) return;
    disposed = true;
    _projection = null;
  }
}
