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
    required this.structuralOrder,
    required this.registrationOrder,
    this.reversibleOriginIdentity,
    this.completesAtSource = false,
    this.controllerLease,
  }) : morphAnimation = CurvedAnimation(
         parent: flightAnimation,
         curve: curve,
       ) {
    _registeredCaptures = {
      ..._MorphDescendantSnapshots.capturesOf(source),
      ..._MorphDescendantSnapshots.capturesOf(destination),
    };
    for (final capture in _registeredCaptures) {
      capture.retain();
    }
    flight = MorphFlight<Object?>(
      source: source,
      destination: destination,
      kind: kind,
      curvedAnimation: morphAnimation,
      uncurvedAnimation: flightAnimation,
      flightDelegate: delegate,
    ).._geometry = geometry;
    flightAnimation.addStatusListener(_handleStatusChanged);
    _watchesDestination = watchDestination;
    if (_watchesDestination) {
      _watchedView = View.of(destinationHandle.owner.context);
      _watchedDescendantRevision = destinationHandle.descendantRevision;
      _watchedPixelRatio = _watchedView.devicePixelRatio;
      flightAnimation.addListener(_scheduleDestinationWatch);
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
  final int structuralOrder;
  final int registrationOrder;
  final Object? reversibleOriginIdentity;
  final bool completesAtSource;
  final _MorphControllerLease? controllerLease;
  final CurvedAnimation morphAnimation;
  late final MorphFlight<Object?> flight;
  final _MorphFlightPaintHandle _paintHandle = _MorphFlightPaintHandle();
  late final Set<_MorphDescendantCapture> _registeredCaptures;
  late final _MorphDescendantCapture? _watchedCapture = _MorphDescendantSnapshots.captureOf(
    completesAtSource ? source : destination,
  );
  late final bool _watchesDestination;
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
  bool _destinationWatchScheduled = false;
  late final ui.FlutterView _watchedView;
  int _watchedDescendantRevision = 0;
  double _watchedPixelRatio = 1;
  int? _deferredCaptureSignature;
  int? _reportedCaptureFailureSignature;
  late final FrameCallback _destinationWatchCallback = _updateWatchedDestination;
  List<_MorphVisibilityHandle> _heldAncestorVisibilities = const [];
  bool _heldAtEndpoint = false;
  bool _heldArrived = false;
  bool _heldReturned = false;
  bool _completionCallbacksInvoked = false;
  bool _heldReleaseScheduled = false;
  bool _endpointHandoffPending = false;
  bool _endpointHandoffCompleted = false;
  bool _endpointHandoffReleaseScheduled = false;
  bool _cohortCompleted = false;
  bool _heldForCohort = false;
  bool _returningToSource = false;
  bool _finished = false;
  _MorphEndpointHandle? _endpointHandoffWinner;
  int _requiredPresentationGeneration = 0;
  late final FrameCallback _endpointHandoffCallback = _completeEndpointHandoff;
  late final ({
    MorphFlightDelegate<Object?> delegate,
    MorphFlight<Object?> flight,
  })
  _renderFlight = _resolveRenderFlight();

  _MorphNavigationRequest? _landingNavigation;
  ModalRoute<Object?>? _routeHandoffWait;
  int _routeHandoffGeneration = 0;
  bool _routeHandoffCompleted = false;

  bool get routeHandoffCompleted => _routeHandoffCompleted;

  void updateLandingNavigation(_MorphNavigationRequest? request) {
    _landingNavigation = request;
    _routeHandoffWait = null;
    _routeHandoffGeneration += 1;
    _routeHandoffCompleted = false;
  }

  bool holdForDepartingRoute(
    _MorphEndpointHandle winner, {
    required bool arrived,
    required bool returned,
  }) {
    final request = _landingNavigation;
    if (_finished ||
        winner.animationsDisabled ||
        request == null ||
        request.cancelled ||
        request.kind != MorphFlightKind.routePop ||
        !identical(request.destination, winner.route)) {
      return false;
    }
    final route = request.source;
    if (route is! ModalRoute<Object?> ||
        route.offstage ||
        (route.barrierColor?.a ?? 0) == 0 ||
        !route.overlayEntries.any((entry) => entry.mounted)) {
      return false;
    }
    if (identical(_routeHandoffWait, route)) return true;
    _routeHandoffWait = route;
    final generation = ++_routeHandoffGeneration;
    // Route.popped resolves before the barrier exits. completed resolves only
    // after the route's overlay entries, including that barrier, are removed.
    unawaited(
      route.completed.then((_) {
        if (_finished || generation != _routeHandoffGeneration) return;
        _landingNavigation = null;
        _routeHandoffWait = null;
        _routeHandoffCompleted = true;
        coordinator.finish(this, arrived: arrived, returned: returned);
      }),
    );
    return true;
  }

  bool get heldAtEndpoint => _heldAtEndpoint;
  bool get heldArrived => _heldArrived;
  bool get heldReturned => _heldReturned;
  bool get heldForCohort => _heldForCohort;
  bool get blocksCohortCompletion => !_cohortCompleted && !_finished;
  bool get hasIndependentClock => controllerLease != null && kind.isRoute;
  bool get isReturningToSource => _returningToSource;

  void continueToDestination() {
    if (!hasIndependentClock || !_returningToSource || _finished) return;
    _returningToSource = false;
    controllerLease!.forward();
  }

  void returnToSource() {
    if (!hasIndependentClock || _returningToSource || _finished) return;
    _returningToSource = true;
    controllerLease!.reverse();
  }

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
    required _MorphEndpointHandle winner,
    required bool arrived,
    required bool returned,
  }) {
    if (_endpointHandoffPending || _endpointHandoffCompleted) return false;
    _clearHeldAncestorListeners();
    _heldArrived = arrived;
    _heldReturned = returned;
    _endpointHandoffPending = true;
    _endpointHandoffWinner = winner;
    _requiredPresentationGeneration = winner.presentationGeneration + 1;
    _paintHandle.prepareHandoff();
    winner.presentationRequested = true;
    winner.owner._requestPresentation();
    SchedulerBinding.instance.ensureVisualUpdate();
    return true;
  }

  void endpointPresented(_MorphEndpointHandle endpoint) {
    if (_finished ||
        !_endpointHandoffPending ||
        _endpointHandoffReleaseScheduled ||
        !identical(endpoint, _endpointHandoffWinner) ||
        endpoint.presentationGeneration < _requiredPresentationGeneration) {
      return;
    }
    _paintHandle.hideDuringPreparedPaint();
    _endpointHandoffReleaseScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback(
      _endpointHandoffCallback,
    );
  }

  MorphEndpoint<Object?> get currentSource {
    return geometry?._sourceWithOwnedTransform(source.properties) ?? source;
  }

  MorphEndpoint<Object?> get currentDestination {
    return geometry?._destinationWithOwnedTransform(destination.properties) ?? destination;
  }

  MorphEndpoint<Object?> sample() {
    return delegate._interpolateEndpoint(
      currentSource,
      currentDestination,
      progress: flight._progress,
    );
  }

  void _publishWatchedDestination({
    required _MorphEndpointGeometry value,
    List<_MorphDescendantFlightRecord>? descendants,
  }) {
    final flightGeometry = geometry;
    if (flightGeometry == null) return;
    if (completesAtSource) {
      flightGeometry.updateSource(value);
    } else {
      flightGeometry.updateDestination(value);
    }
    if (descendants == null) return;
    _watchedCapture?.replaceRecords(descendants);
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
            child: ExcludeSemantics(
              child: _MorphFlightScope(
                coordinator: coordinator,
                registeredCaptures: _registeredCaptures,
                child: retainedFlight,
              ),
            ),
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
                    coordinator: coordinator,
                    registeredCaptures: _registeredCaptures,
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
      if (typedDelegate.switchTransition != null || _watchesDestination) {
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
    updateLandingNavigation(null);
    _clearPresentationRequest();
    _endpointHandoffWinner = null;
    coordinator._flightEnded(this);
    _clearHeldAncestorListeners();
    _paintHandle.hide();
    if (_watchesDestination) {
      flightAnimation.removeListener(_scheduleDestinationWatch);
    }
    flightAnimation.removeStatusListener(_handleStatusChanged);
    for (final capture in _registeredCaptures) {
      capture.release();
    }
    morphAnimation.dispose();
    controllerLease?.release();
    geometry?.dispose();
  }

  void _handleStatusChanged(AnimationStatus status) {
    if (_finished || _heldAtEndpoint || (!status.isCompleted && !status.isDismissed)) {
      return;
    }
    if (hasIndependentClock) {
      coordinator.finish(
        this,
        arrived: status.isCompleted,
        returned: status.isDismissed && completesAtSource,
      );
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
    if (_watchesDestination) {
      _scheduleDestinationWatch();
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
    final winner = _endpointHandoffWinner;
    if (winner == null || !winner.active || winner.disposed) {
      _endpointHandoffReleaseScheduled = false;
      return;
    }
    _endpointHandoffReleaseScheduled = false;
    _endpointHandoffPending = false;
    _endpointHandoffCompleted = true;
    _clearPresentationRequest();
    _endpointHandoffWinner = null;
    winner.owner._requestPresentation();
    coordinator._releaseEndpointHandoff(this);
  }

  void _clearPresentationRequest() {
    _endpointHandoffWinner?.presentationRequested = false;
  }

  void _scheduleDestinationWatch() {
    if (_finished || _destinationWatchScheduled) return;
    _destinationWatchScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback(
      _destinationWatchCallback,
    );
  }

  void _updateWatchedDestination(Duration _) {
    _destinationWatchScheduled = false;
    if (_finished || destinationHandle.disposed || !destinationHandle.active || !watchDestination) {
      return;
    }
    int? captureFailureSignature;
    try {
      final watchedGeometry = destinationHandle.owner._readLiveGeometry();
      if (watchedGeometry != null) {
        final destinationRecords = _watchedCapture?.records ?? const <_MorphDescendantFlightRecord>[];
        final pixelRatio = _watchedView.devicePixelRatio;
        final recordsChanged = _watchedDescendantsChanged(
          destinationRecords,
          pixelRatio,
        );
        if (recordsChanged && _watchedCapture != null) {
          captureFailureSignature = _captureFailureSignature(
            destinationRecords,
            pixelRatio,
          );
          if (captureFailureSignature != _deferredCaptureSignature) {
            final refreshedRecords = destinationHandle._refreshDescendants(
              previousRecords: destinationRecords,
              pixelRatioChanged: pixelRatio != _watchedPixelRatio,
            );
            if (refreshedRecords == null) {
              _deferredCaptureSignature = captureFailureSignature;
            } else {
              _publishWatchedDestination(
                value: watchedGeometry,
                descendants: refreshedRecords,
              );
              _watchedDescendantRevision = destinationHandle.descendantRevision;
              _watchedPixelRatio = pixelRatio;
              _deferredCaptureSignature = null;
              _reportedCaptureFailureSignature = null;
            }
          }
        } else {
          _publishWatchedDestination(value: watchedGeometry);
        }
      }
    } on Object catch (exception, stack) {
      if (captureFailureSignature == null || captureFailureSignature != _reportedCaptureFailureSignature) {
        _reportedCaptureFailureSignature = captureFailureSignature;
        coordinator._reportCaptureError(
          destinationHandle,
          exception,
          stack,
        );
      }
    }
    if (_heldAtEndpoint || _heldForCohort) {
      _scheduleDestinationWatch();
    }
  }

  int _captureFailureSignature(
    List<_MorphDescendantFlightRecord> records,
    double pixelRatio,
  ) {
    var signature = Object.hash(
      destinationHandle.descendantRevision,
      pixelRatio,
    );
    for (final record in records) {
      signature = Object.hash(
        signature,
        identityHashCode(record.handle),
        record.handle.snapshotRevision,
      );
    }
    return signature;
  }

  bool _watchedDescendantsChanged(
    List<_MorphDescendantFlightRecord> records,
    double pixelRatio,
  ) {
    if (destinationHandle.descendantRevision != _watchedDescendantRevision || pixelRatio != _watchedPixelRatio) {
      return true;
    }
    for (final record in records) {
      if ((record.capturesContinuously && (!record.snapshotCaptureCompleted || record.snapshot != null)) ||
          record.handle.snapshotDirty ||
          record.snapshotRevision != record.handle.snapshotRevision) {
        return true;
      }
    }
    return false;
  }
}
