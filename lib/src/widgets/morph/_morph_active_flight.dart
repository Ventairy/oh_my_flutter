part of 'morph.dart';

class _MorphActiveFlight {
  new({
    required this.coordinator,
    required this.tag,
    required this.sourceHandle,
    required this.destinationHandle,
    required this.delegate,
    required this.source,
    required this.destination,
    required this.kind,
    required Animation<double> parentAnimation,
    required this.curve,
    required this.reverseCurve,
    required this.playbackDuration,
    required this.playbackReverseDuration,
    required this.hasConfiguredForwardDuration,
    required this.hasConfiguredReverseDuration,
    required this.watchDestination,
    required this.onStart,
    required this.onEnd,
    required this.cohort,
    required this.structuralOrder,
    required this.registrationOrder,
    this.reversibleOriginIdentity,
    this.completesAtSource = false,
    this.controllerLease,
  }) {
    flightAnimation = ProxyAnimation(parentAnimation);
    _initialCurveAnimation = CurvedAnimation(
      parent: flightAnimation,
      curve: curve,
      reverseCurve: reverseCurve,
    );
    morphAnimation = ProxyAnimation(_initialCurveAnimation);
    _registeredCaptures = {
      ..._MorphDescendantSnapshots.capturesOf(source),
      ..._MorphDescendantSnapshots.capturesOf(destination),
    };
    for (final capture in _registeredCaptures) {
      _retainCapture(
        capture,
        visibility: _MorphDescendantSnapshots.capturesOf(destination).contains(capture)
            ? destinationHandle.visibility
            : sourceHandle?.visibility,
      );
    }
    flight = MorphFlight<Object?>._(
      source: source,
      destination: destination,
      kind: kind,
      curvedAnimation: morphAnimation,
      uncurvedAnimation: flightAnimation,
      flightDelegate: delegate,
      endpointState: geometry,
      resolveEndpointProperties: null,
    );
    flightAnimation.addStatusListener(_handleStatusChanged);
    _watchesDestination = watchDestination;
    if (_watchesDestination) {
      _watchedView = View.of(destinationHandle.owner.context);
      _watchedDescendantRevision = destinationHandle.descendantRevision;
      _watchedPixelRatio = _watchedView.devicePixelRatio;
      if (destinationHandle.visibility.hasContentGroups) {
        _watchedDestinationPaintRelease = destinationHandle.visibility.beginHiddenPaint();
      }
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
  late final ProxyAnimation flightAnimation;
  final Curve curve;
  final Curve reverseCurve;
  final Duration playbackDuration;
  final Duration playbackReverseDuration;
  final bool hasConfiguredForwardDuration;
  final bool hasConfiguredReverseDuration;
  final bool watchDestination;
  final VoidCallback? onStart;
  final VoidCallback? onEnd;
  final Object cohort;
  final int structuralOrder;
  final int registrationOrder;
  final Object? reversibleOriginIdentity;
  final bool completesAtSource;
  _MorphControllerLease? controllerLease;
  CurvedAnimation? _initialCurveAnimation;
  late final ProxyAnimation morphAnimation;
  late final MorphFlight<Object?> flight;
  late final _MorphFlightPaintHandle _paintHandle = _MorphFlightPaintHandle(
    onRetiredPainted: _handleFlightRetiredPainted,
  );
  late final Set<_MorphDescendantCapture> _registeredCaptures;
  final Map<_MorphDescendantCapture, VoidCallback> _groupPresentationReleases = {};
  late _MorphDescendantCapture? _watchedCapture = _MorphDescendantSnapshots.captureOf(
    completesAtSource ? source : destination,
  );
  late ({MorphTarget target, MorphEndpoint<Object?> endpoint}) _watchedEndpoint = (
    target: destinationHandle.target,
    endpoint: completesAtSource ? source : destination,
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
  late int _watchedCaptureRevision = destinationHandle.captureRevision;
  double _watchedPixelRatio = 1;
  int? _deferredCaptureSignature;
  bool _deferredCaptureRetryPending = false;
  int? _reportedCaptureFailureSignature;
  VoidCallback? _watchedDestinationPaintRelease;
  late final FrameCallback _destinationWatchCallback = _updateWatchedDestination;
  List<_MorphVisibilityHandle> _heldAncestorVisibilities = const [];
  bool _heldAtEndpoint = false;
  bool _heldArrived = false;
  bool _heldReturned = false;
  bool _completionCallbacksInvoked = false;
  bool _heldReleaseScheduled = false;
  bool _endpointHandoffPending = false;
  bool _endpointHandoffCompleted = false;
  bool _endpointHandoffPresentationReady = false;
  bool _endpointHandoffReleaseScheduled = false;
  int _presentedEndpointRevision = 0;
  bool _endpointHandoffAwaitsWatchedEndpoint = false;
  bool _endpointHandoffAllowsStaleWatchedEndpoint = false;
  bool _cohortCompleted = false;
  bool _heldForCohort = false;
  bool _returningToSource = false;
  bool _finished = false;
  _MorphEndpointHandle? _endpointHandoffWinner;
  int _requiredPresentationGeneration = 0;
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
  bool get endpointHandoffPresentationReady => _endpointHandoffPresentationReady;
  bool get hasIndependentClock => controllerLease != null && kind.isRoute;
  bool get isReturningToSource => _returningToSource;

  void continueToDestination() {
    if (!_returningToSource || _finished) return;
    _returningToSource = false;
    _rebaseCurve(curve, towardDestination: true);
    controllerLease?.forward();
  }

  void returnToSource() {
    if (_returningToSource || _finished) return;
    _cancelEndpointHandoffForReversal();
    _clearHeldAncestorListeners();
    _heldForCohort = false;
    _cohortCompleted = false;
    _returningToSource = true;
    _rebaseCurve(reverseCurve, towardDestination: false);
    final controllerLease = this.controllerLease;
    if (controllerLease != null) {
      controllerLease.reverse();
      return;
    }
    if (hasConfiguredReverseDuration) {
      coordinator._takeOverRouteClock(this).reverse();
    }
  }

  void _rebaseCurve(
    Curve curve, {
    required bool towardDestination,
  }) {
    final initialProgress = flightAnimation.value.clamp(0.0, 1.0);
    final remainingProgress = towardDestination ? 1 - initialProgress : initialProgress;
    if (remainingProgress == 0) return;

    final initialValue = morphAnimation.value;
    final destinationValue = towardDestination ? 1.0 : 0.0;
    morphAnimation.parent = flightAnimation.drive(
      Animatable<double>.fromCallback((progress) {
        final elapsed = towardDestination
            ? (progress - initialProgress) / remainingProgress
            : (initialProgress - progress) / remainingProgress;
        return ui.lerpDouble(
          initialValue,
          destinationValue,
          curve.transform(elapsed.clamp(0.0, 1.0)),
        )!;
      }),
    );
    _initialCurveAnimation?.dispose();
    _initialCurveAnimation = null;
  }

  void adoptControllerLease(_MorphControllerLease controllerLease) {
    assert(this.controllerLease == null, 'The flight already owns its clock.');
    this.controllerLease = controllerLease;
    flightAnimation.parent = controllerLease.controller;
  }

  void _cancelEndpointHandoffForReversal() {
    if (!_endpointHandoffPending) return;
    final winner = _endpointHandoffWinner;
    winner?.presentationRequested = false;
    winner?.visibility.hidden = true;
    _endpointHandoffWinner = null;
    _endpointHandoffPending = false;
    _endpointHandoffPresentationReady = false;
    _endpointHandoffReleaseScheduled = false;
    _endpointHandoffAwaitsWatchedEndpoint = false;
    _endpointHandoffAllowsStaleWatchedEndpoint = false;
    _presentedEndpointRevision = 0;
    _paintHandle.resumeAfterPreparedHandoff();
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
    _endpointHandoffPresentationReady = false;
    _endpointHandoffWinner = winner;
    _endpointHandoffAllowsStaleWatchedEndpoint = false;
    _requiredPresentationGeneration = winner.presentationGeneration + 1;
    _endpointHandoffAwaitsWatchedEndpoint = _watchedDestinationNeedsRefresh();
    if (!_endpointHandoffAwaitsWatchedEndpoint) {
      _promoteWatchedEndpointForHandoff();
      _paintHandle.prepareHandoff();
    }
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
    if (!_endpointHandoffAllowsStaleWatchedEndpoint && _watchedDestinationNeedsRefresh()) {
      _endpointHandoffAwaitsWatchedEndpoint = true;
      _scheduleDestinationWatch();
      return;
    }
    if (_endpointHandoffAwaitsWatchedEndpoint) {
      _promoteWatchedEndpointForHandoff();
      _prepareWatchedEndpointHandoff();
      return;
    }
    _endpointHandoffPresentationReady = true;
    coordinator._endpointHandoffPresentationReady(this);
  }

  void endpointPresentationInvalidated(_MorphEndpointHandle endpoint) {
    if (_finished ||
        !_endpointHandoffPending ||
        _endpointHandoffReleaseScheduled ||
        !identical(endpoint, _endpointHandoffWinner)) {
      return;
    }
    _endpointHandoffPresentationReady = false;
    _requiredPresentationGeneration = endpoint.presentationGeneration + 1;
    endpoint.presentationRequested = true;
    endpoint.owner._requestPresentation();
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void retirePresentedEndpoint() {
    if (_finished ||
        !_endpointHandoffPending ||
        !_endpointHandoffPresentationReady ||
        _endpointHandoffReleaseScheduled) {
      return;
    }
    _paintHandle.retireDuringPreparedPaint();
    _endpointHandoffReleaseScheduled = true;
    _presentedEndpointRevision = geometry?.revision ?? 0;
  }

  void _handleFlightRetiredPainted() {
    if (_finished || !_endpointHandoffPending || !_endpointHandoffReleaseScheduled) {
      return;
    }
    final presentedEndpointRevision = _presentedEndpointRevision;
    SchedulerBinding.instance.addPostFrameCallback(
      (timeStamp) => _completeEndpointHandoff(
        timeStamp,
        presentedEndpointRevision: presentedEndpointRevision,
      ),
    );
  }

  MorphEndpoint<Object?> get currentSource {
    return geometry?._sourceWithOwnedTransform<Object?>() ?? source;
  }

  MorphEndpoint<Object?> get currentDestination {
    return geometry?._destinationWithOwnedTransform<Object?>() ?? destination;
  }

  MorphEndpoint<Object?> sample() {
    return delegate._interpolateEndpoint(
      currentSource,
      currentDestination,
      progress: flight._progress,
    );
  }

  void _publishWatchedDestination(
    MorphEndpoint<Object?> endpoint, {
    required MorphTarget target,
  }) {
    final flightGeometry = geometry;
    if (flightGeometry == null) return;
    final previousCapture = _watchedCapture;
    final replacementCapture = _MorphDescendantSnapshots.captureOf(endpoint);
    if (replacementCapture != null && !_registeredCaptures.contains(replacementCapture)) {
      _registeredCaptures.add(replacementCapture);
      _retainCapture(
        replacementCapture,
        visibility: destinationHandle.visibility,
      );
    }
    _watchedEndpoint = (target: target, endpoint: endpoint);
    if (_endpointHandoffPending) {
      _promoteWatchedEndpointForHandoff();
    }
    if (completesAtSource) {
      flightGeometry.updateSourceEndpoint(endpoint);
    } else {
      flightGeometry.updateDestinationEndpoint(endpoint);
    }
    if (_endpointHandoffPending) {
      _prepareWatchedEndpointHandoff();
    }
    _watchedCapture = replacementCapture;
    if (previousCapture == null || identical(previousCapture, replacementCapture)) {
      return;
    }
    if (_registeredCaptures.remove(previousCapture)) {
      _releaseCapture(previousCapture);
    }
  }

  void _promoteWatchedEndpointForHandoff() {
    if (!_watchesDestination || !identical(_endpointHandoffWinner, destinationHandle)) {
      return;
    }
    final watchedEndpoint = _watchedEndpoint;
    destinationHandle._cacheWatchedEndpoint(
      target: watchedEndpoint.target,
      endpoint: watchedEndpoint.endpoint,
    );
  }

  void _retainCapture(
    _MorphDescendantCapture capture, {
    required _MorphVisibilityHandle? visibility,
  }) {
    capture.retain();
    _groupPresentationReleases[capture] = capture.beginGroupPresentation(visibility);
  }

  void _releaseCapture(_MorphDescendantCapture capture) {
    _groupPresentationReleases.remove(capture)?.call();
    capture.release();
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
    if (_watchesDestination) return null;
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
      if (typedDelegate.switchTransition != null) {
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
    _endpointHandoffAllowsStaleWatchedEndpoint = false;
    coordinator._flightEnded(this);
    _clearHeldAncestorListeners();
    if (_endpointHandoffCompleted) {
      _paintHandle.finishPreparedHandoff();
    } else {
      _paintHandle.hide();
    }
    if (_watchesDestination) {
      flightAnimation.removeListener(_scheduleDestinationWatch);
    }
    _watchedDestinationPaintRelease?.call();
    _watchedDestinationPaintRelease = null;
    flightAnimation.removeStatusListener(_handleStatusChanged);
    _registeredCaptures.forEach(_releaseCapture);
    _groupPresentationReleases.clear();
    _registeredCaptures.clear();
    _initialCurveAnimation?.dispose();
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

  void _completeEndpointHandoff(
    Duration _, {
    required int presentedEndpointRevision,
  }) {
    if (_finished || !_endpointHandoffPending) return;
    final winner = _endpointHandoffWinner;
    if (winner == null || !winner.active || winner.disposed) {
      _endpointHandoffReleaseScheduled = false;
      return;
    }
    if ((geometry?.revision ?? 0) != presentedEndpointRevision) {
      _endpointHandoffPresentationReady = false;
      _endpointHandoffReleaseScheduled = false;
      _prepareWatchedEndpointHandoff();
      return;
    }
    _endpointHandoffReleaseScheduled = false;
    _endpointHandoffPending = false;
    _endpointHandoffCompleted = true;
    _endpointHandoffPresentationReady = false;
    _clearPresentationRequest();
    _endpointHandoffWinner = null;
    _endpointHandoffAllowsStaleWatchedEndpoint = false;
    winner.owner._requestPresentation();
    coordinator._releaseEndpointHandoff(this);
  }

  void _clearPresentationRequest() {
    _endpointHandoffWinner?.presentationRequested = false;
  }

  void _prepareWatchedEndpointHandoff() {
    final winner = _endpointHandoffWinner;
    if (_finished || !_endpointHandoffPending || winner == null || winner.disposed || !winner.active) {
      return;
    }
    _endpointHandoffAwaitsWatchedEndpoint = false;
    _endpointHandoffPresentationReady = false;
    _endpointHandoffReleaseScheduled = false;
    _requiredPresentationGeneration = winner.presentationGeneration + 1;
    _paintHandle.prepareHandoff();
    winner.presentationRequested = true;
    winner.owner._requestPresentation();
    SchedulerBinding.instance.ensureVisualUpdate();
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
      final watchedGeometry = destinationHandle.owner._readSettledLiveGeometry();
      if (watchedGeometry != null) {
        final destinationRecords = _watchedCapture?.records ?? const <_MorphDescendantFlightRecord>[];
        final pixelRatio = _watchedView.devicePixelRatio;
        final recordsChanged = _watchedDescendantsChanged(
          destinationRecords,
          pixelRatio,
        );
        final flightGeometry = geometry!;
        final geometryChanged = completesAtSource
            ? !flightGeometry.sourceMatches(watchedGeometry)
            : !flightGeometry.destinationMatches(watchedGeometry);
        final groupsChanged = !(_watchedCapture?.groupsAreCurrent ?? true);
        final propertiesChanged = destinationHandle.captureRevision != _watchedCaptureRevision;
        if (geometryChanged || groupsChanged || recordsChanged || propertiesChanged) {
          captureFailureSignature = _captureFailureSignature(
            destinationRecords,
            pixelRatio,
            watchedGeometry,
            groupRevisionSignature: _watchedCapture?.groupRevisionSignature,
          );
          if (captureFailureSignature != _deferredCaptureSignature || _deferredCaptureRetryPending) {
            final retriesDeferredCapture = captureFailureSignature == _deferredCaptureSignature;
            _deferredCaptureRetryPending = false;
            final target = destinationHandle.target;
            final endpoint = destinationHandle.owner._captureWatchedEndpoint(
              target: target,
              geometry: watchedGeometry,
              previousRecords: destinationRecords,
              pixelRatioChanged: pixelRatio != _watchedPixelRatio,
            );
            if (endpoint == null) {
              _deferredCaptureSignature = captureFailureSignature;
              _deferredCaptureRetryPending = !retriesDeferredCapture;
              if (retriesDeferredCapture) {
                _allowStaleWatchedEndpointHandoff();
              }
            } else {
              _publishWatchedDestination(endpoint, target: target);
              _watchedDescendantRevision = destinationHandle.descendantRevision;
              _watchedCaptureRevision = destinationHandle.captureRevision;
              _watchedPixelRatio = pixelRatio;
              _deferredCaptureSignature = null;
              _deferredCaptureRetryPending = false;
              _reportedCaptureFailureSignature = null;
              _endpointHandoffAllowsStaleWatchedEndpoint = false;
            }
          } else {
            _allowStaleWatchedEndpointHandoff();
          }
        }
      }
    } on Object catch (exception, stack) {
      final failedCaptureSignature =
          captureFailureSignature ??
          Object.hash(
            destinationHandle.descendantRevision,
            destinationHandle.captureRevision,
            _watchedView.devicePixelRatio,
          );
      _deferredCaptureSignature = failedCaptureSignature;
      _deferredCaptureRetryPending = false;
      if (failedCaptureSignature != _reportedCaptureFailureSignature) {
        _reportedCaptureFailureSignature = failedCaptureSignature;
        coordinator._reportCaptureError(
          destinationHandle,
          exception,
          stack,
        );
      }
      _allowStaleWatchedEndpointHandoff();
    }
    if (_heldAtEndpoint || _heldForCohort || _deferredCaptureRetryPending) {
      _scheduleDestinationWatch();
    }
  }

  void _allowStaleWatchedEndpointHandoff() {
    if (!_endpointHandoffPending || _endpointHandoffAllowsStaleWatchedEndpoint) {
      return;
    }
    _endpointHandoffAllowsStaleWatchedEndpoint = true;
    _prepareWatchedEndpointHandoff();
  }

  bool _watchedDestinationNeedsRefresh() {
    if (!_watchesDestination || destinationHandle.disposed || !destinationHandle.active) {
      return false;
    }
    final watchedGeometry = destinationHandle.owner._readLiveGeometry();
    if (watchedGeometry == null) return true;
    final destinationRecords = _watchedCapture?.records ?? const <_MorphDescendantFlightRecord>[];
    final pixelRatio = _watchedView.devicePixelRatio;
    final groupsAreCurrent = _watchedCapture?.groupsAreCurrent ?? true;
    final flightGeometry = geometry!;
    final geometryChanged = completesAtSource
        ? !flightGeometry.sourceMatches(watchedGeometry)
        : !flightGeometry.destinationMatches(watchedGeometry);
    return geometryChanged ||
        !groupsAreCurrent ||
        _watchedDescendantsChanged(
          destinationRecords,
          pixelRatio,
          includeContinuousCaptures: false,
        ) ||
        destinationHandle.captureRevision != _watchedCaptureRevision;
  }

  int _captureFailureSignature(
    List<_MorphDescendantFlightRecord> records,
    double pixelRatio,
    _MorphEndpointGeometry geometry, {
    required int? groupRevisionSignature,
  }) {
    var signature = Object.hash(
      destinationHandle.descendantRevision,
      destinationHandle.captureRevision,
      pixelRatio,
      geometry.overlayBounds,
      geometry.localSize,
      geometry.axisScale,
      Object.hashAll(geometry.transform.storage),
      groupRevisionSignature,
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
    double pixelRatio, {
    bool includeContinuousCaptures = true,
  }) {
    if (destinationHandle.descendantRevision != _watchedDescendantRevision || pixelRatio != _watchedPixelRatio) {
      return true;
    }
    for (final record in records) {
      if ((includeContinuousCaptures &&
              record.capturesContinuously &&
              (!record.snapshotCaptureCompleted || record.snapshot != null)) ||
          record.handle.snapshotDirty ||
          record.snapshotRevision != record.handle.snapshotRevision) {
        return true;
      }
    }
    return false;
  }
}
