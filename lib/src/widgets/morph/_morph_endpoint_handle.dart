part of 'morph.dart';

class _MorphEndpointHandle {
  new({
    required this.owner,
    required this.targets,
    required this.visibility,
    required this.overlay,
    required this.route,
    required this.observer,
    required this.parentEndpoint,
  }) {
    target = targets.first;
    configurationChanged();
  }

  final _MorphState owner;
  final _MorphVisibilityHandle visibility;
  final OverlayState overlay;
  final ModalRoute<Object?>? route;
  _MorphEndpointHandle? parentEndpoint;

  final MorphNavigatorObserver? observer;
  List<MorphTarget> targets;
  late MorphTarget target;
  MorphTarget? preparedTarget;

  Object get tag => target;
  late MorphFlightDelegate<Object?> delegate;
  Duration? get configuredDuration => target.duration ?? parentEndpoint?.configuredDuration;
  Duration? get configuredReverseDuration =>
      target.reverseDuration ?? target.duration ?? parentEndpoint?.configuredReverseDuration;
  Duration get duration => configuredDuration ?? Morph._defaultDuration;
  Duration get reverseDuration => configuredReverseDuration ?? Morph._defaultDuration;
  Curve get curve => target.curve ?? parentEndpoint?.curve ?? Morph._defaultCurve;
  Curve get reverseCurve => target.reverseCurve ?? target.curve ?? parentEndpoint?.reverseCurve ?? Morph._defaultCurve;
  VoidCallback? onStart;
  VoidCallback? onEnd;
  VoidCallback? onReceived;
  MorphEndpoint<Object?>? _cachedEndpoint;
  MorphTarget? _cachedTarget;
  bool captureFailed = false;
  _MorphDescendantCapture? _cachedGroupCapture;
  VoidCallback? _releaseCachedGroupPresentation;

  void releaseGroupCache() {
    _releaseCachedGroupPresentation?.call();
    _releaseCachedGroupPresentation = null;
    _cachedGroupCapture?.release();
    _cachedGroupCapture = null;
  }

  final Set<_MorphDescendantCapture> _departureCaptures = {};
  final Map<MorphTarget, MorphEndpoint<Object?>> _departureEndpoints = {};
  List<_MorphDescendantFlightRecord>? _departureRecords;
  int? _departureDescendantRevision;
  int registrationOrder = 0;
  bool alternativesResolved = false;
  bool alternativeMatchAvailable = true;
  int? structuralOrder;
  int presentationGeneration = 0;
  bool presentationRequested = false;
  int retentionGeneration = 0;
  bool active = true;
  bool disposed = false;
  bool animationsDisabled = false;

  MorphEndpoint<Object?>? _sameFrameEndpoint;
  MorphTarget? _sameFrameTarget;
  final List<_MorphDescendantHandle> _descendants = [];
  int _descendantRegistrationOrder = 0;
  int _descendantRevision = 0;
  int _captureRevision = 0;

  int get descendantRevision => _descendantRevision;
  int get captureRevision => _captureRevision;

  void captureChanged() => _captureRevision += 1;

  bool get flightsEnabled => owner._scopeEnabled;

  void _registerDescendant(_MorphDescendantHandle descendant) {
    if (_descendants.contains(descendant)) return;
    descendant.registrationOrder = ++_descendantRegistrationOrder;
    _descendants.add(descendant);
    _descendantRevision += 1;
  }

  void _unregisterDescendant(_MorphDescendantHandle descendant) {
    if (!_descendants.remove(descendant)) return;
    _descendantRevision += 1;
  }

  void _descendantChanged(_MorphDescendantHandle descendant) {
    if (_descendants.contains(descendant)) _descendantRevision += 1;
  }

  List<_MorphDescendantFlightRecord> _captureDescendants({bool allowDetached = false}) {
    return _buildDescendantRecords(
      previousRecords: const [],
      pixelRatioChanged: true,
      refresh: false,
      rejectStaleCapture: false,
      allowDetached: allowDetached,
    )!;
  }

  List<_MorphDescendantFlightRecord>? _refreshDescendants({
    required List<_MorphDescendantFlightRecord> previousRecords,
    required bool pixelRatioChanged,
  }) {
    return _buildDescendantRecords(
      previousRecords: previousRecords,
      pixelRatioChanged: pixelRatioChanged,
      refresh: true,
      rejectStaleCapture: true,
    );
  }

  List<_MorphDescendantFlightRecord>? _buildDescendantRecords({
    required List<_MorphDescendantFlightRecord> previousRecords,
    required bool pixelRatioChanged,
    required bool refresh,
    required bool rejectStaleCapture,
    bool allowDetached = false,
  }) {
    if (_descendants.isEmpty) return const [];
    final candidates =
        <
          ({
            _MorphDescendantHandle handle,
            _RenderMorphDescendant renderObject,
          })
        >[];
    final boundaries = <_RenderMorphDescendant>{};
    for (final descendant in _descendants) {
      final renderObject = descendant.capturableRenderObject(allowDetached: allowDetached);
      if (renderObject == null) continue;
      candidates.add((handle: descendant, renderObject: renderObject));
      boundaries.add(renderObject);
    }
    final previousByHandle = <_MorphDescendantHandle, _MorphDescendantFlightRecord>{
      for (final record in previousRecords) record.handle: record,
    };
    final records = <_MorphDescendantFlightRecord>[];
    final allSnapshotRecords = <_MorphDescendantFlightRecord>[];
    final allSnapshotRenderObjects = <_RenderMorphDescendant>[];
    final snapshotRecords = <_MorphDescendantFlightRecord>[];
    final snapshotRenderObjects = <_RenderMorphDescendant>[];
    var retainedSnapshotPhysicalPixels = 0;
    var replacesAllRetainedSnapshots = false;
    double? pixelRatio;
    for (final candidate in candidates) {
      final renderObject = candidate.renderObject;
      if (_hasDescendantBoundaryAncestor(renderObject, boundaries)) continue;
      final descendant = candidate.handle;
      final previous = previousByHandle[descendant];
      final behavior = descendant.owner.widget.flightBehavior;
      final canReuseSnapshot = refresh && previous != null && previous.behavior.usesSnapshot && behavior.usesSnapshot;
      final record = descendant.capture(
        renderObject,
        previous: previous,
        snapshot: canReuseSnapshot ? previous.snapshot : null,
        snapshotCaptureCompleted: canReuseSnapshot && previous.snapshotCaptureCompleted,
        capturesContinuously: refresh && previous != null && !descendant.snapshotDirty && previous.behavior == behavior
            ? previous.capturesContinuously
            : null,
      );
      records.add(record);
      if (!record.behavior.usesSnapshot) continue;
      if (record.size.isEmpty) {
        record
          ..snapshot = null
          ..snapshotCaptureCompleted = true;
        continue;
      }
      allSnapshotRecords.add(record);
      allSnapshotRenderObjects.add(renderObject);
      final snapshotChanged =
          !refresh ||
          pixelRatioChanged ||
          previous == null ||
          descendant.snapshotDirty ||
          (record.capturesContinuously && !(previous.snapshotCaptureCompleted && previous.snapshot == null)) ||
          previous.behavior != record.behavior ||
          previous.size != record.size ||
          previous.childType != record.childType ||
          previous.key != record.key;
      if (!snapshotChanged) continue;
      pixelRatio ??= View.of(owner.context).devicePixelRatio;
      snapshotRecords.add(record);
      snapshotRenderObjects.add(renderObject);
    }
    if (snapshotRecords.isNotEmpty) {
      replacesAllRetainedSnapshots = snapshotRecords.length == allSnapshotRecords.length;
      if (refresh && !replacesAllRetainedSnapshots) {
        final projection = _snapshotPhysicalPixelProjection(
          records: records,
          replacedRecords: snapshotRecords,
          replacementRenderObjects: snapshotRenderObjects,
          pixelRatio: pixelRatio!,
        );
        retainedSnapshotPhysicalPixels = projection.retained;
        if (projection.total > _MorphSnapshotCapture._maximumCapturePhysicalPixels) {
          final originallyReplacedRecords = Set<_MorphDescendantFlightRecord>.identity()..addAll(snapshotRecords);
          snapshotRecords.clear();
          snapshotRenderObjects.clear();
          for (var index = 0; index < allSnapshotRecords.length; index += 1) {
            final record = allSnapshotRecords[index];
            if (record.snapshot == null && !originallyReplacedRecords.contains(record)) {
              continue;
            }
            snapshotRecords.add(record);
            snapshotRenderObjects.add(allSnapshotRenderObjects[index]);
          }
          replacesAllRetainedSnapshots = true;
          retainedSnapshotPhysicalPixels = 0;
        }
      }
      final capture = _MorphSnapshotCapture.captureAll(
        pixelRatio: pixelRatio!,
        renderObjects: snapshotRenderObjects,
      );
      if (capture == null) {
        if (refresh) return null;
        for (final record in snapshotRecords) {
          record.snapshotCaptureCompleted = true;
        }
      } else {
        for (var index = 0; index < snapshotRecords.length; index += 1) {
          snapshotRecords[index]
            ..snapshot = capture.snapshots[index]
            ..snapshotCaptureCompleted = true;
        }
        if (refresh &&
            !replacesAllRetainedSnapshots &&
            retainedSnapshotPhysicalPixels + capture.physicalPixels >
                _MorphSnapshotCapture._maximumCapturePhysicalPixels) {
          return null;
        }
      }
    }
    if (rejectStaleCapture &&
        records.any(
          (record) => record.snapshotRevision != record.handle.snapshotRevision,
        )) {
      return null;
    }
    for (final record in records) {
      record.handle.acceptSnapshotRevision(record.snapshotRevision);
    }
    return records;
  }

  ({int retained, int total}) _snapshotPhysicalPixelProjection({
    required List<_MorphDescendantFlightRecord> records,
    required List<_MorphDescendantFlightRecord> replacedRecords,
    required List<_RenderMorphDescendant> replacementRenderObjects,
    required double pixelRatio,
  }) {
    final replaced = Set<_MorphDescendantFlightRecord>.identity()..addAll(replacedRecords);
    final retainedAtlases = Set<SnapshotAtlas>.identity();
    for (final record in records) {
      if (!replaced.contains(record)) {
        record.snapshot?.addAtlasesTo(retainedAtlases);
      }
    }
    var retainedPixels = 0;
    for (final atlas in retainedAtlases) {
      retainedPixels += atlas.physicalPixels;
    }
    return (
      retained: retainedPixels,
      total:
          retainedPixels +
          _MorphSnapshotCapture._plannedCapturePhysicalPixels(
            pixelRatio: pixelRatio,
            renderObjects: replacementRenderObjects,
          ),
    );
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
    delegate = owner._resolvedFlightDelegate;
    visibility.setContentGroups(delegate.contentGroups);
    onStart = widget.onStart;
    onEnd = widget.onEnd;
    onReceived = widget.onReceived;
    if (owner.mounted) {
      animationsDisabled = MediaQuery.maybeDisableAnimationsOf(owner.context) ?? false;
    }
  }

  void _cacheCapture(MorphTarget target, MorphEndpoint<Object?> endpoint) {
    final capture = _MorphDescendantSnapshots.captureOf(endpoint);
    final groupCapture = capture != null && capture.hasGroups ? capture : null;
    if (!identical(groupCapture, _cachedGroupCapture)) {
      groupCapture?.retain();
      releaseGroupCache();
      _cachedGroupCapture = groupCapture;
      _releaseCachedGroupPresentation = groupCapture?.beginGroupPresentation(visibility);
    }
    _cachedEndpoint = endpoint;
    _cachedTarget = target;
    _sameFrameEndpoint = endpoint;
    _sameFrameTarget = target;
    scheduleMicrotask(() {
      if (identical(_sameFrameEndpoint, endpoint)) {
        _sameFrameEndpoint = null;
        _sameFrameTarget = null;
      }
    });
  }

  void _cacheWatchedEndpoint({
    required MorphTarget target,
    required MorphEndpoint<Object?> endpoint,
  }) {
    if (!active || disposed || !identical(this.target, target)) return;
    _cacheCapture(target, endpoint);
  }

  void captureDeparture(MorphTarget candidate) {
    // Only descendant pixels are shared across alternatives. The delegate still
    // resolves each target's properties and group snapshots independently.
    final sharedRecords = _departureRecords;
    final capturedEndpoint = owner._captureLastPainted(
      target: candidate,
      departureRecords: sharedRecords,
      departureDescendantRevision: _departureDescendantRevision,
    );
    if (capturedEndpoint == null) return;
    final descendantCapture = _MorphDescendantSnapshots.captureOf(capturedEndpoint);
    if (descendantCapture != null && !identical(descendantCapture.records, sharedRecords)) {
      _departureRecords = descendantCapture.records;
      _departureDescendantRevision = _descendantRevision;
    }
    for (final capture in _MorphDescendantSnapshots.capturesOf(capturedEndpoint)) {
      if (_departureCaptures.add(capture)) capture.retain();
    }
    _departureEndpoints[candidate] = capturedEndpoint;
    if (identical(candidate, target)) _cacheCapture(candidate, capturedEndpoint);
  }

  void releaseDeparture() {
    for (final capture in _departureCaptures) {
      capture.release();
    }
    _departureCaptures.clear();
    _departureEndpoints.clear();
    _departureRecords = null;
    _departureDescendantRevision = null;
  }

  MorphEndpoint<Object?>? capture({required MorphTarget target, bool reuseSameFrame = false}) {
    final sameFrameEndpoint = _sameFrameEndpoint;
    if (reuseSameFrame && identical(_sameFrameTarget, target) && sameFrameEndpoint != null) {
      return sameFrameEndpoint;
    }
    if (active && owner.mounted) {
      final capturedEndpoint = owner._capture(target: target);
      if (capturedEndpoint != null) {
        _cacheCapture(target, capturedEndpoint);
      }
    }
    return identical(_cachedTarget, target) ? _cachedEndpoint : _departureEndpoints[target];
  }
}
