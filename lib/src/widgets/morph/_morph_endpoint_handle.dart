part of 'morph.dart';

class _MorphEndpointHandle {
  _MorphEndpointHandle({
    required this.owner,
    required this.visibility,
    required this.overlay,
    required this.route,
    required this.parentEndpoint,
  }) {
    configurationChanged();
  }

  final _MorphState owner;
  final _MorphVisibilityHandle visibility;
  final OverlayState overlay;
  final ModalRoute<Object?>? route;
  _MorphEndpointHandle? parentEndpoint;

  late Object tag;
  late MorphFlightDelegate<Object?> delegate;
  late Duration duration;
  late Curve curve;
  late bool watchDestination;
  VoidCallback? onStart;
  VoidCallback? onEnd;
  VoidCallback? onReceived;
  MorphEndpoint<Object?>? cachedEndpoint;
  int registrationOrder = 0;
  int retentionGeneration = 0;
  bool active = true;
  bool disposed = false;
  bool animationsDisabled = false;
  MorphEndpoint<Object?>? _sameFrameEndpoint;
  final List<_MorphDescendantHandle> _descendants = [];
  int _descendantRegistrationOrder = 0;

  void _registerDescendant(_MorphDescendantHandle descendant) {
    if (_descendants.contains(descendant)) return;
    descendant.registrationOrder = ++_descendantRegistrationOrder;
    _descendants.add(descendant);
  }

  void _unregisterDescendant(_MorphDescendantHandle descendant) {
    _descendants.remove(descendant);
  }

  List<_MorphDescendantFlightRecord> _captureDescendants() {
    if (_descendants.isEmpty) return const [];
    final ordered = List<_MorphDescendantHandle>.of(_descendants)
      ..sort((first, second) => first.registrationOrder.compareTo(second.registrationOrder));
    final candidates =
        <
          ({
            _MorphDescendantHandle handle,
            _RenderMorphDescendant renderObject,
          })
        >[];
    final boundaries = <_RenderMorphDescendant>{};
    for (final descendant in ordered) {
      final renderObject = descendant.capturableRenderObject;
      if (renderObject == null) continue;
      candidates.add((handle: descendant, renderObject: renderObject));
      boundaries.add(renderObject);
    }
    final records = <_MorphDescendantFlightRecord>[];
    final snapshotRecords = <_MorphDescendantFlightRecord>[];
    final snapshotRenderObjects = <_RenderMorphDescendant>[];
    double? pixelRatio;
    for (final candidate in candidates) {
      final renderObject = candidate.renderObject;
      if (_hasDescendantBoundaryAncestor(renderObject, boundaries)) continue;
      final descendant = candidate.handle;
      final record = descendant.capture(renderObject);
      records.add(record);
      if (!record.behavior.usesSnapshot || record.size.isEmpty) continue;
      pixelRatio ??= View.of(descendant.owner.context).devicePixelRatio;
      snapshotRecords.add(record);
      snapshotRenderObjects.add(renderObject);
    }
    if (snapshotRecords.isNotEmpty) {
      final snapshots = _MorphContentSnapshot.captureAll(
        pixelRatio: pixelRatio!,
        renderObjects: snapshotRenderObjects,
      );
      for (var index = 0; index < snapshotRecords.length; index += 1) {
        snapshotRecords[index].snapshot = snapshots[index];
      }
    }
    return records;
  }

  bool _hasDescendantBoundaryAncestor(
    _RenderMorphDescendant renderObject,
    Set<_RenderMorphDescendant> boundaries,
  ) {
    var ancestor = renderObject.parent;
    while (ancestor != null) {
      if (ancestor case final _RenderMorphDescendant boundary when boundaries.contains(boundary)) {
        return true;
      }
      ancestor = ancestor.parent;
    }
    return false;
  }

  void configurationChanged() {
    final widget = owner.widget;
    tag = widget.tag;
    delegate = owner._resolvedFlightDelegate;
    duration = widget.duration ?? parentEndpoint?.duration ?? Morph._defaultDuration;
    curve = widget.curve ?? parentEndpoint?.curve ?? Morph._defaultCurve;
    watchDestination = widget.watchDestination;
    onStart = widget.onStart;
    onEnd = widget.onEnd;
    onReceived = widget.onReceived;
    if (owner.mounted) {
      animationsDisabled = MediaQuery.maybeDisableAnimationsOf(owner.context) ?? false;
    }
  }

  void _cacheCapture(MorphEndpoint<Object?> endpoint) {
    cachedEndpoint = endpoint;
    _sameFrameEndpoint = endpoint;
    scheduleMicrotask(() {
      if (identical(_sameFrameEndpoint, endpoint)) {
        _sameFrameEndpoint = null;
      }
    });
  }

  void captureDeparture() {
    final capturedEndpoint = owner._captureLastPainted();
    if (capturedEndpoint != null) {
      _cacheCapture(capturedEndpoint);
    }
  }

  MorphEndpoint<Object?>? capture({bool reuseSameFrame = false}) {
    final sameFrameEndpoint = _sameFrameEndpoint;
    if (reuseSameFrame && sameFrameEndpoint != null) {
      return sameFrameEndpoint;
    }
    if (active && owner.mounted) {
      final capturedEndpoint = owner._capture();
      if (capturedEndpoint != null) {
        _cacheCapture(capturedEndpoint);
      }
    }
    return cachedEndpoint;
  }
}
