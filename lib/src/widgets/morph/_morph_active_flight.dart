part of 'morph.dart';

class _MorphActiveFlight {
  _MorphActiveFlight({
    required this.coordinator,
    required this.tag,
    required this.sourceHandle,
    required this.destinationHandle,
    required this.delegate,
    required this.source,
    required this.destination,
    required this.kind,
    required this.flightAnimation,
    required this.curve,
    required this.watchDestination,
    required this.onStart,
    required this.onEnd,
    required this.cohort,
    this.reversibleOriginIdentity,
    this.completesAtSource = false,
    this.controllerLease,
  }) : morphAnimation = CurvedAnimation(
         parent: flightAnimation,
         curve: curve,
       ) {
    flight = MorphFlight<Object?>(
      source: source,
      destination: destination,
      kind: kind,
      animation: morphAnimation,
      flightDelegate: delegate,
    ).._geometry = geometry;
    flightAnimation.addStatusListener(_handleStatusChanged);
    for (final record in _sourceDescendants) {
      record.retain();
    }
    for (final record in _destinationDescendants) {
      record.retain();
    }
    _watchesDestinationGeometry = watchDestination;
    if (_watchesDestinationGeometry) {
      flightAnimation.addListener(_scheduleGeometryWatch);
    }
  }

  final _MorphCoordinator coordinator;
  final Object tag;
  final _MorphEndpointHandle? sourceHandle;
  final _MorphEndpointHandle destinationHandle;
  final MorphFlightDelegate<Object?> delegate;
  final MorphEndpoint<Object?> source;
  final MorphEndpoint<Object?> destination;
  final MorphFlightKind kind;
  final Animation<double> flightAnimation;
  final Curve curve;
  final bool watchDestination;
  final VoidCallback? onStart;
  final VoidCallback? onEnd;
  final Object cohort;
  final Object? reversibleOriginIdentity;
  final bool completesAtSource;
  final _MorphControllerLease? controllerLease;
  final CurvedAnimation morphAnimation;
  late final MorphFlight<Object?> flight;
  final _MorphFlightPaintHandle _paintHandle = _MorphFlightPaintHandle();
  late final List<_MorphDescendantFlightRecord> _sourceDescendants = _MorphDescendantSnapshots.of(source);
  late final List<_MorphDescendantFlightRecord> _destinationDescendants = _MorphDescendantSnapshots.of(destination);
  late final _MorphDescendantFlightResolver? _descendantFlightResolver =
      _sourceDescendants.isEmpty && _destinationDescendants.isEmpty
      ? null
      : _MorphDescendantFlightResolver(
          animation: morphAnimation,
          switchThreshold: switch (delegate) {
            _MorphAutomaticFlightDelegate(:final switchThreshold) => switchThreshold,
            _ => 0.5,
          },
          source: _sourceDescendants,
          destination: _destinationDescendants,
        );
  late final bool _watchesDestinationGeometry;
  late final _MorphFlightGeometry? geometry = watchDestination
      ? _MorphFlightGeometry(
          source: source,
          destination: destination,
        )
      : null;
  Widget? _retainedFlight;
  Widget? _fallbackFlight;
  TextDirection? _retainedFlightTextDirection;
  bool _retainedFlightResolved = false;
  bool _geometryWatchScheduled = false;
  late final FrameCallback _geometryWatchCallback = _updateWatchedGeometry;
  List<_MorphVisibilityHandle> _heldAncestorVisibilities = const [];
  bool _heldAtEndpoint = false;
  bool _heldArrived = false;
  bool _heldReturned = false;
  bool _completionCallbacksInvoked = false;
  bool _heldReleaseScheduled = false;
  bool _endpointHandoffPending = false;
  bool _endpointHandoffCompleted = false;
  bool _cohortCompleted = false;
  bool _heldForCohort = false;
  bool _finished = false;
  late final FrameCallback _endpointHandoffCallback = _completeEndpointHandoff;
  late final ({
    MorphFlightDelegate<Object?> delegate,
    MorphFlight<Object?> flight,
  })
  _renderFlight = _resolveRenderFlight();

  bool get heldAtEndpoint => _heldAtEndpoint;
  bool get heldArrived => _heldArrived;
  bool get heldReturned => _heldReturned;
  bool get heldForCohort => _heldForCohort;
  bool get blocksCohortCompletion => !_cohortCompleted && !_finished;

  void markCohortCompleted() {
    _cohortCompleted = true;
  }

  void holdForCohort({
    required bool arrived,
    required bool returned,
  }) {
    _heldArrived = arrived;
    _heldReturned = returned;
    _heldForCohort = true;
  }

  void releaseCohortHold() {
    _heldForCohort = false;
  }

  bool beginEndpointHandoff({
    required bool arrived,
    required bool returned,
  }) {
    if (_endpointHandoffPending || _endpointHandoffCompleted) return false;
    _clearHeldAncestorListeners();
    _heldArrived = arrived;
    _heldReturned = returned;
    _endpointHandoffPending = true;
    SchedulerBinding.instance.addPostFrameCallback(
      _endpointHandoffCallback,
    );
    SchedulerBinding.instance.ensureVisualUpdate();
    return true;
  }

  MorphEndpoint<Object?> get currentSource {
    return geometry?._sourceWithOwnedTransform(source.properties) ?? source;
  }

  MorphEndpoint<Object?> get currentDestination {
    return geometry?._destinationWithOwnedTransform(destination.properties) ?? destination;
  }

  MorphEndpoint<Object?> sample() {
    final progress = morphAnimation.value;
    return delegate._interpolateEndpoint(
      currentSource,
      currentDestination,
      progress: progress,
    );
  }

  void updateDestinationGeometry(_MorphEndpointGeometry value) {
    final geometry = this.geometry;
    if (geometry == null) return;
    geometry.updateDestination(value);
  }

  void updateSourceGeometry(_MorphEndpointGeometry value) {
    final geometry = this.geometry;
    if (geometry == null) return;
    geometry.updateSource(value);
  }

  Widget build(BuildContext context) {
    if (_finished) return const SizedBox.shrink();
    final renderFlight = _renderFlight;
    final retainedFlight = _buildRetainedFlight(
      context,
      typedDelegate: renderFlight.delegate,
      typedFlight: renderFlight.flight,
    );
    if (retainedFlight != null) {
      return Positioned.fill(
        child: _buildFlightBoundary(
          child: IgnorePointer(
            child: ExcludeSemantics(child: retainedFlight),
          ),
        ),
      );
    }

    if ((_endpointHandoffPending || _heldAtEndpoint || _heldForCohort) && _fallbackFlight != null) {
      return _fallbackFlight!;
    }

    return _fallbackFlight = Positioned.fill(
      child: _buildAncestorFlightBoundary(
        child: _MorphPositionedFlight(
          animation: morphAnimation,
          geometry: geometry,
          sourceBounds: source.bounds,
          destinationBounds: destination.bounds,
          child: RepaintBoundary(
            child: _MorphFlightBoundary(
              paintHandle: _paintHandle,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: _MorphFlightScope(
                    descendantResolver: _descendantFlightResolver,
                    child: renderFlight.delegate._buildErasedFlight(
                      context,
                      renderFlight.flight,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAncestorFlightBoundary({required Widget child}) {
    final ancestor = coordinator._sharedAncestorFlight(this);
    if (ancestor == null) return child;
    return _MorphFlightBoundary(
      paintHandle: _paintHandle,
      ancestorAnimation: ancestor.morphAnimation,
      ancestorGeometry: ancestor.geometry,
      ancestorSourceBounds: ancestor.source.bounds,
      ancestorDestinationBounds: ancestor.destination.bounds,
      child: child,
    );
  }

  Widget _buildFlightBoundary({required Widget child}) {
    final ancestor = coordinator._sharedAncestorFlight(this);
    return _MorphFlightBoundary(
      paintHandle: _paintHandle,
      ancestorAnimation: ancestor?.morphAnimation,
      ancestorGeometry: ancestor?.geometry,
      ancestorSourceBounds: ancestor?.source.bounds,
      ancestorDestinationBounds: ancestor?.destination.bounds,
      child: child,
    );
  }

  ({
    MorphFlightDelegate<Object?> delegate,
    MorphFlight<Object?> flight,
  })
  _resolveRenderFlight() {
    if (delegate case final _MorphAutomaticFlightDelegate automatic) {
      return automatic._specializedFlight(flight) ?? (delegate: delegate, flight: flight);
    }
    return (delegate: delegate, flight: flight);
  }

  Widget? _buildRetainedFlight(
    BuildContext context, {
    required MorphFlightDelegate<Object?> typedDelegate,
    required MorphFlight<Object?> typedFlight,
  }) {
    if (_descendantFlightResolver != null) return null;
    if (typedDelegate is MorphTextFlightDelegate) {
      if (_retainedFlightResolved) return _retainedFlight;
      _retainedFlightResolved = true;
      final sourceProperties = typedFlight._sourceProperties;
      final destinationProperties = typedFlight._destinationProperties;
      if (sourceProperties is! MorphTextProperties || destinationProperties is! MorphTextProperties) {
        return null;
      }
      if (!typedDelegate._supportsRetainedFlight(
        sourceProperties,
        destinationProperties,
      )) {
        return null;
      }
      if (typedDelegate._usesSwitchTransition(
        sourceProperties,
        destinationProperties,
      )) {
        return null;
      }
      return _retainedFlight = typedDelegate._buildErasedFlight(
        context,
        typedFlight,
        rasterPool: coordinator.textRasterPool,
      );
    }

    if (typedDelegate is MorphContainerFlightDelegate) {
      final textDirection = Directionality.of(context);
      if (_retainedFlightResolved && textDirection == _retainedFlightTextDirection) {
        return _retainedFlight;
      }
      final sourceProperties = typedFlight._sourceProperties;
      final destinationProperties = typedFlight._destinationProperties;
      if (sourceProperties is! MorphContainerProperties || destinationProperties is! MorphContainerProperties) {
        return null;
      }
      if (typedDelegate.switchTransition != null &&
          MorphChildFlightDelegate._specializedTextChanges(
            sourceProperties,
            destinationProperties,
          )) {
        _retainedFlightResolved = true;
        return _retainedFlight = null;
      }
      final plan = _MorphCompoundFlightPlan.forContainer(
        source: sourceProperties,
        destination: destinationProperties,
        textDirection: textDirection,
      );
      _retainedFlightResolved = true;
      _retainedFlightTextDirection = textDirection;
      if (plan != null) {
        return _retainedFlight = _MorphCompoundFlight(
          animation: morphAnimation,
          plan: plan,
          rasterPool: coordinator.textRasterPool,
          sourceBounds: source.bounds,
          destinationBounds: destination.bounds,
          geometry: geometry,
        );
      }
      if (typedDelegate.switchTransition != null || _watchesDestinationGeometry) {
        return _retainedFlight = null;
      }
      final hybridPlan = _MorphHybridContainerFlightPlan.tryCreate(
        source: sourceProperties,
        destination: destinationProperties,
        textDirection: textDirection,
      );
      if (hybridPlan == null) return _retainedFlight = null;
      return _retainedFlight = _MorphHybridContainerFlight(
        animation: morphAnimation,
        plan: hybridPlan,
        transitionBuilder: typedDelegate.switchTransition,
        sourceBounds: source.bounds,
        destinationBounds: destination.bounds,
        geometry: geometry,
      );
    }

    if (typedDelegate is MorphColumnFlightDelegate) {
      final textDirection = Directionality.of(context);
      if (_retainedFlightResolved && textDirection == _retainedFlightTextDirection) {
        return _retainedFlight;
      }
      final sourceProperties = typedFlight._sourceProperties;
      final destinationProperties = typedFlight._destinationProperties;
      if (sourceProperties is! MorphColumnProperties || destinationProperties is! MorphColumnProperties) {
        return null;
      }
      if (typedDelegate.switchTransition != null &&
          MorphChildFlightDelegate._specializedTextChanges(
            sourceProperties,
            destinationProperties,
          )) {
        _retainedFlightResolved = true;
        return _retainedFlight = null;
      }
      final plan = _MorphCompoundFlightPlan.forColumn(
        source: sourceProperties,
        destination: destinationProperties,
        textDirection: textDirection,
      );
      _retainedFlightResolved = true;
      _retainedFlightTextDirection = textDirection;
      if (plan != null) {
        return _retainedFlight = _MorphCompoundFlight(
          animation: morphAnimation,
          plan: plan,
          rasterPool: coordinator.textRasterPool,
          sourceBounds: source.bounds,
          destinationBounds: destination.bounds,
          geometry: geometry,
        );
      }
      final hybridPlan = _MorphHybridColumnFlightPlan.tryCreate(
        source: sourceProperties,
        destination: destinationProperties,
        textDirection: textDirection,
      );
      if (hybridPlan == null) return _retainedFlight = null;
      return _retainedFlight = _MorphHybridColumnFlight(
        animation: morphAnimation,
        plan: hybridPlan,
        transitionBuilder: typedDelegate.switchTransition,
        rasterPool: coordinator.textRasterPool,
        sourceBounds: source.bounds,
        destinationBounds: destination.bounds,
        geometry: geometry,
      );
    }
    return null;
  }

  void start() {
    try {
      onStart?.call();
    } on Object catch (exception, stack) {
      coordinator
        ..cancelAfterStartFailure(this)
        ..reportCallbackError(
          tag: tag,
          callback: 'onStart',
          exception: exception,
          stack: stack,
        );
      return;
    }
    controllerLease?.start();
  }

  void cancelForRetarget() => _finish();

  void dispose() => _finish();

  void _finish() {
    if (_finished) return;
    _finished = true;
    coordinator._flightEnded(this);
    _clearHeldAncestorListeners();
    _paintHandle.hide();
    if (_watchesDestinationGeometry) {
      flightAnimation.removeListener(_scheduleGeometryWatch);
    }
    flightAnimation.removeStatusListener(_handleStatusChanged);
    for (final record in _sourceDescendants) {
      record.release();
    }
    for (final record in _destinationDescendants) {
      record.release();
    }
    _descendantFlightResolver?.dispose();
    morphAnimation.dispose();
    controllerLease?.release();
    geometry?.dispose();
  }

  void _handleStatusChanged(AnimationStatus status) {
    if (_finished || _heldAtEndpoint || (!status.isCompleted && !status.isDismissed)) {
      return;
    }
    scheduleMicrotask(
      () => coordinator.finish(
        this,
        arrived: status.isCompleted,
        returned: status.isDismissed && completesAtSource,
      ),
    );
  }

  bool holdAtEndpoint(
    _MorphEndpointHandle endpoint, {
    required bool arrived,
    required bool returned,
  }) {
    final ancestorVisibilities = <_MorphVisibilityHandle>[];
    var ancestor = endpoint.parentEndpoint;
    while (ancestor != null) {
      if (coordinator._flightUses(ancestor)) {
        ancestorVisibilities.add(ancestor.visibility);
      }
      ancestor = ancestor.parentEndpoint;
    }
    if (!ancestorVisibilities.any((visibility) => visibility.hidden)) {
      return false;
    }

    _heldAtEndpoint = true;
    _heldArrived = arrived;
    _heldReturned = returned;
    _heldAncestorVisibilities = ancestorVisibilities;
    for (final visibility in ancestorVisibilities) {
      visibility.addListener(_handleHeldAncestorVisibilityChanged);
    }
    if (_watchesDestinationGeometry) {
      _scheduleGeometryWatch();
    }
    return true;
  }

  void _handleHeldAncestorVisibilityChanged() {
    if (_finished || !_heldAtEndpoint || _heldReleaseScheduled) return;
    if (_heldAncestorVisibilities.any((visibility) => visibility.hidden)) {
      return;
    }
    _heldReleaseScheduled = true;
    scheduleMicrotask(() {
      _heldReleaseScheduled = false;
      if (!_finished && _heldAtEndpoint) {
        coordinator._releaseHeldFlight(this);
      }
    });
  }

  void _clearHeldAncestorListeners() {
    for (final visibility in _heldAncestorVisibilities) {
      visibility.removeListener(_handleHeldAncestorVisibilityChanged);
    }
    _heldAncestorVisibilities = const [];
    _heldAtEndpoint = false;
    _heldReleaseScheduled = false;
  }

  void _completeEndpointHandoff(Duration _) {
    if (_finished || !_endpointHandoffPending) return;
    _endpointHandoffPending = false;
    _endpointHandoffCompleted = true;
    coordinator._releaseEndpointHandoff(this);
  }

  void _scheduleGeometryWatch() {
    if (_finished || _geometryWatchScheduled) return;
    _geometryWatchScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback(
      _geometryWatchCallback,
    );
  }

  void _updateWatchedGeometry(Duration _) {
    _geometryWatchScheduled = false;
    if (_finished || destinationHandle.disposed || !destinationHandle.active || !watchDestination) {
      return;
    }
    final watchedGeometry = destinationHandle.owner._readLiveGeometry();
    if (watchedGeometry != null) {
      coordinator.geometryChanged(destinationHandle, watchedGeometry);
    }
    if (_heldAtEndpoint) {
      _scheduleGeometryWatch();
    }
  }
}
