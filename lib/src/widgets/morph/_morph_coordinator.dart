part of 'morph.dart';

class _MorphCoordinator extends ChangeNotifier {
  _MorphCoordinator._(this.overlay);

  factory _MorphCoordinator.of(OverlayState overlay) {
    return _coordinators[overlay] ??= _MorphCoordinator._(overlay);
  }

  static final Expando<_MorphCoordinator> _coordinators = Expando<_MorphCoordinator>('oh_my_flutter.morph');

  final OverlayState overlay;
  final Map<Object, List<_MorphEndpointHandle>> _endpoints = {};
  final Map<Object, _MorphActiveFlight> _flights = {};
  final List<_MorphActiveFlight> _orderedFlights = [];
  final Map<Object, _MorphEndpointHandle> _owners = {};
  final Map<Object, List<_MorphEndpointHandle>> _pendingRouteEndpoints = {};
  final Set<_MorphEndpointHandle> _scheduledIncomingEndpoints = {};
  final List<_MorphSiblingHandle> _siblings = [];
  final List<_MorphSiblingHandle> _visibleSiblings = [];
  final Map<Duration, _MorphControllerLease> _sameFrameControllers = {};
  final _MorphTextRasterPool textRasterPool = _MorphTextRasterPool();
  OverlayEntry? _overlayEntry;
  Object? _sameFrameCohort;
  int _registrationOrder = 0;
  bool _notificationScheduled = false;
  bool _structuralOrderRefreshScheduled = false;

  Iterable<_MorphActiveFlight> get flights => _orderedFlights;

  List<_MorphSiblingHandle> siblingsAbove(
    _MorphActiveFlight flight,
  ) {
    _visibleSiblings.clear();
    for (final sibling in _siblings) {
      if (!sibling.active ||
          sibling.disposed ||
          !sibling.paintsAboveMorph ||
          !sibling.canPaint ||
          sibling.tag != flight.tag) {
        continue;
      }
      if (_siblingParticipates(flight, sibling)) {
        _visibleSiblings.add(sibling);
      }
    }
    return _visibleSiblings;
  }

  void registerSibling(_MorphSiblingHandle sibling) {
    sibling
      ..active = true
      ..disposed = false;
    if (!_siblings.contains(sibling)) _siblings.add(sibling);
    _attachSiblingFlight(sibling);
    if (_hasScheduledIncomingFlightUsingSibling(sibling)) {
      sibling.prepareForIncomingFlight();
    } else if (!_hasFlightUsingSibling(sibling)) {
      sibling.settleTransition();
    }
    if (_hasFlightUsingSibling(sibling)) {
      _notifyListenersSafely();
    }
  }

  void siblingGeometryChanged(_MorphSiblingHandle sibling) {
    if (!_siblings.contains(sibling)) return;
    if (_hasProjectedFlightUsingSibling(sibling)) {
      sibling.changed();
      if (!sibling.isProjected) _notifyListenersSafely();
    }
  }

  void deactivateSibling(_MorphSiblingHandle sibling) {
    sibling
      ..active = false
      ..resetFlight();
    if (_overlayEntry != null) _notifyListenersSafely();
  }

  void activateSibling(_MorphSiblingHandle sibling) {
    sibling
      ..active = true
      ..disposed = false;
    _attachSiblingFlight(sibling);
    if (_hasScheduledIncomingFlightUsingSibling(sibling)) {
      sibling.prepareForIncomingFlight();
    } else if (!_hasFlightUsingSibling(sibling)) {
      sibling.settleTransition();
    }
    if (_hasFlightUsingSibling(sibling)) {
      sibling.changed();
      _notifyListenersSafely();
    }
  }

  void unregisterSibling(_MorphSiblingHandle sibling) {
    sibling
      ..active = false
      ..visibility.hidden = false;
    _siblings.remove(sibling);
    _visibleSiblings.remove(sibling);
    sibling.dispose();
    if (_overlayEntry != null) _notifyListenersSafely();
  }

  bool showsSibling(_MorphSiblingHandle sibling) {
    if (!sibling.paintsAboveMorph || !sibling.canPaint) return false;
    final flight = _flights[sibling.tag];
    return flight != null && _siblingParticipates(flight, sibling);
  }

  ModalRoute<Object?>? _siblingRoute(_MorphActiveFlight flight) {
    if (flight.completesAtSource) return flight.sourceHandle?.route;
    return flight.destinationHandle.route;
  }

  bool _siblingParticipates(
    _MorphActiveFlight flight,
    _MorphSiblingHandle sibling,
  ) {
    if (identical(_siblingRoute(flight), sibling.route)) return true;
    return sibling.hasTransition &&
        !identical(flight.sourceHandle?.route, flight.destinationHandle.route) &&
        identical(flight.sourceHandle?.route, sibling.route);
  }

  Animation<double>? _siblingAnimation(
    _MorphActiveFlight flight,
    _MorphSiblingHandle sibling,
  ) {
    if (!_siblingParticipates(flight, sibling)) return null;
    if (identical(flight.sourceHandle?.route, sibling.route) &&
        !identical(flight.sourceHandle?.route, flight.destinationHandle.route)) {
      return ReverseAnimation(flight.morphAnimation);
    }
    return flight.morphAnimation;
  }

  bool _hasFlightUsingSibling(_MorphSiblingHandle sibling) {
    final flight = _flights[sibling.tag];
    return flight != null && _siblingParticipates(flight, sibling);
  }

  bool _hasProjectedFlightUsingSibling(_MorphSiblingHandle sibling) {
    return sibling.paintsAboveMorph && _hasFlightUsingSibling(sibling);
  }

  bool _hasScheduledIncomingFlightUsingSibling(
    _MorphSiblingHandle sibling,
  ) {
    if (!sibling.hasTransition) return false;
    for (final endpoint in _scheduledIncomingEndpoints) {
      if (endpoint.tag == sibling.tag &&
          identical(endpoint.route, sibling.route) &&
          endpoint.active &&
          !endpoint.disposed) {
        return true;
      }
    }
    return false;
  }

  void _prepareSiblingsForIncomingFlight(
    _MorphEndpointHandle destination,
  ) {
    for (final sibling in _siblings) {
      if (!sibling.active ||
          sibling.disposed ||
          sibling.tag != destination.tag ||
          !identical(sibling.route, destination.route)) {
        continue;
      }
      sibling.prepareForIncomingFlight();
    }
  }

  void _installFlight(_MorphActiveFlight flight) {
    final replaced = _flights[flight.tag];
    if (replaced != null) _orderedFlights.remove(replaced);
    _flights[flight.tag] = flight;
    var insertionIndex = 0;
    while (insertionIndex < _orderedFlights.length &&
        _compareFlightOrder(_orderedFlights[insertionIndex], flight) <= 0) {
      insertionIndex += 1;
    }
    _orderedFlights.insert(insertionIndex, flight);
    for (final sibling in _siblings) {
      if (!sibling.active || sibling.tag != flight.tag) continue;
      final animation = _siblingAnimation(flight, sibling);
      if (animation != null) sibling.attachFlight(flight, animation);
    }
  }

  int _compareFlightOrder(
    _MorphActiveFlight first,
    _MorphActiveFlight second,
  ) {
    final structuralComparison = first.structuralOrder.compareTo(
      second.structuralOrder,
    );
    if (structuralComparison != 0) return structuralComparison;
    return first.registrationOrder.compareTo(second.registrationOrder);
  }

  _MorphActiveFlight? _removeFlight(Object tag) {
    final flight = _flights.remove(tag);
    if (flight != null) _orderedFlights.remove(flight);
    return flight;
  }

  void _scheduleStructuralOrderRefresh() {
    if (_structuralOrderRefreshScheduled) return;
    _structuralOrderRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _structuralOrderRefreshScheduled = false;
      if (!overlay.mounted) return;
      _refreshStructuralOrder();
    });
  }

  void _refreshStructuralOrder() {
    var order = 0;

    void visit(Element element) {
      if (element case StatefulElement(:final state) when state is _MorphState) {
        final endpoint = state._endpoint;
        if (endpoint != null && identical(endpoint.overlay, overlay) && endpoint.active && !endpoint.disposed) {
          endpoint.structuralOrder = ++order;
        }
      }
      element.visitChildren(visit);
    }

    overlay.context.visitChildElements(visit);
  }

  void _attachSiblingFlight(_MorphSiblingHandle sibling) {
    if (!sibling.active) return;
    final flight = _flights[sibling.tag];
    if (flight == null) return;
    final animation = _siblingAnimation(flight, sibling);
    if (animation != null) sibling.attachFlight(flight, animation);
  }

  void geometryChanged(
    _MorphEndpointHandle endpoint,
    _MorphEndpointGeometry geometry,
  ) {
    final flight = _flights[endpoint.tag];
    if (flight == null || !flight.watchDestination) return;
    if (identical(flight.destinationHandle, endpoint)) {
      if (flight.completesAtSource) {
        flight.updateSourceGeometry(geometry);
      } else {
        flight.updateDestinationGeometry(geometry);
      }
    }
  }

  void endpointPresented(_MorphEndpointHandle endpoint) {
    final flight = _flights[endpoint.tag];
    if (flight == null) return;
    flight.endpointPresented(endpoint);
  }

  void register(_MorphEndpointHandle endpoint) {
    endpoint
      ..active = true
      ..disposed = false
      ..registrationOrder = ++_registrationOrder
      ..retentionGeneration += 1;
    _endpoints.putIfAbsent(endpoint.tag, () => []).add(endpoint);
    _scheduleStructuralOrderRefresh();

    final candidate = _candidateFor(endpoint);
    if (candidate == null) {
      _claimOwnership(endpoint);
      return;
    }

    if (endpoint.animationsDisabled || candidate.animationsDisabled) {
      _transferOwnershipImmediately(endpoint);
      return;
    }
    endpoint.visibility.hidden = true;
    _scheduledIncomingEndpoints.add(endpoint);
    _prepareSiblingsForIncomingFlight(endpoint);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _scheduledIncomingEndpoints.remove(endpoint);
        _startIncoming(endpoint);
        for (final sibling in _siblings) {
          if (sibling.tag == endpoint.tag &&
              !_hasFlightUsingSibling(sibling) &&
              !_hasScheduledIncomingFlightUsingSibling(sibling)) {
            sibling.settleTransition();
          }
        }
      },
    );
  }

  void configurationChanged(_MorphEndpointHandle endpoint) {
    endpoint.configurationChanged();
    _scheduleStructuralOrderRefresh();
    if (!endpoint.animationsDisabled) return;
    final flight = _flights[endpoint.tag];
    if (flight == null ||
        (!identical(flight.sourceHandle, endpoint) && !identical(flight.destinationHandle, endpoint))) {
      return;
    }
    _transferOwnershipImmediately(flight.destinationHandle);
  }

  void deactivate(_MorphEndpointHandle endpoint) {
    _captureDeparture(endpoint);
    endpoint
      ..active = false
      ..retentionGeneration += 1;
    _scheduleEndpointPurge(
      endpoint,
      endpoint.retentionGeneration,
    );
  }

  void activate(_MorphEndpointHandle endpoint) {
    endpoint
      ..active = true
      ..disposed = false
      ..retentionGeneration += 1;
    _scheduleStructuralOrderRefresh();
  }

  void unregister(_MorphEndpointHandle endpoint) {
    endpoint
      ..active = false
      ..disposed = true
      ..retentionGeneration += 1;
    final flight = _flights[endpoint.tag];
    if (flight != null && identical(flight.destinationHandle, endpoint)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final current = _flights[endpoint.tag];
        if (!identical(current, flight) || endpoint.active) return;
        finish(
          flight,
          arrived: false,
          deferNotification: true,
        );
      });
    }
    _scheduleEndpointPurge(
      endpoint,
      endpoint.retentionGeneration,
    );
  }

  void overlayUnmounted(OverlayEntry unmountedEntry) {
    if (!identical(_overlayEntry, unmountedEntry)) return;
    final flights = _flights.values.toList(growable: false);
    _flights.clear();
    _orderedFlights.clear();
    for (final flight in flights) {
      flight.cancelForRetarget();
    }
    _sameFrameControllers.clear();
    _sameFrameCohort = null;
    final entry = _overlayEntry;
    _overlayEntry = null;
    if (entry != null) {
      scheduleMicrotask(() {
        entry
          ..remove()
          ..dispose();
      });
    }
    scheduleMicrotask(() {
      if (!overlay.mounted) textRasterPool.dispose();
    });
  }

  void replace(
    _MorphEndpointHandle destination, {
    required MorphEndpoint<Object?> source,
    required Object sourceIdentity,
    required Object destinationIdentity,
    required MorphFlightDelegate<Object?> sourceDelegate,
    required Duration duration,
    required Curve curve,
    required bool watchDestination,
    required VoidCallback? onStart,
    required VoidCallback? onEnd,
  }) {
    if (!identical(_owners[destination.tag], destination)) return;

    if (destination.animationsDisabled) {
      _transferOwnershipImmediately(destination);
      return;
    }

    final structuralOrder = destination.structuralOrder ?? destination.registrationOrder;
    final registrationOrder = destination.registrationOrder;
    destination.visibility.hidden = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!destination.active || destination.disposed) return;
      if (!identical(_owners[destination.tag], destination)) return;

      final capturedDestination = _capture(destination);
      if (capturedDestination == null) {
        _claimOwnership(destination);
        _reportSkippedFlight(
          tag: destination.tag,
          reason: 'the destination did not have usable layout',
        );
        return;
      }
      if (!_delegatesAreCompatible(
        sourceDelegate,
        destination.delegate,
      )) {
        _claimOwnership(destination);
        _reportSkippedFlight(
          tag: destination.tag,
          reason: 'endpoint delegate types are incompatible',
        );
        return;
      }

      final existingFlight = _flights[destination.tag];
      if (existingFlight != null) {
        if (existingFlight.kind.isRoute) return;
        _retarget(
          existingFlight,
          destination,
          configuration: (
            duration: duration,
            curve: curve,
            watchDestination: watchDestination,
            onStart: onStart,
            onEnd: onEnd,
            destinationIdentity: destinationIdentity,
          ),
        );
        return;
      }

      final controllerLease = _obtainSameFrameController(duration);
      final flight = _MorphActiveFlight(
        coordinator: this,
        tag: destination.tag,
        sourceHandle: null,
        destinationHandle: destination,
        delegate: sourceDelegate,
        source: source,
        destination: capturedDestination,
        kind: MorphFlightKind.sameScreen,
        flightAnimation: controllerLease.controller,
        curve: curve,
        watchDestination: watchDestination,
        onStart: onStart,
        onEnd: onEnd,
        cohort: _obtainSameFrameCohort(),
        structuralOrder: structuralOrder,
        registrationOrder: registrationOrder,
        reversibleOriginIdentity: sourceIdentity,
        controllerLease: controllerLease,
      );
      _installFlight(flight);
      _ensureOverlay();
      notifyListeners();
      flight.start();
    });
  }

  void replaceFromState(
    _MorphEndpointHandle destination, {
    required MorphEndpoint<Object?>? Function() sourceCapture,
    required Object sourceIdentity,
    required Object destinationIdentity,
    required MorphFlightDelegate<Object?> sourceDelegate,
    required Duration duration,
    required Curve curve,
    required bool watchDestination,
    required VoidCallback? onStart,
    required VoidCallback? onEnd,
  }) {
    if (destination.animationsDisabled) {
      _transferOwnershipImmediately(destination);
      return;
    }
    MorphEndpoint<Object?>? source;
    try {
      source = sourceCapture();
    } on Object catch (exception, stack) {
      _reportCaptureError(destination, exception, stack);
      _transferOwnershipImmediately(destination);
      return;
    }
    if (source == null) {
      _transferOwnershipImmediately(destination);
      _reportSkippedFlight(
        tag: destination.tag,
        reason: 'the departing endpoint did not have usable layout',
      );
      return;
    }
    replace(
      destination,
      source: source,
      sourceIdentity: sourceIdentity,
      destinationIdentity: destinationIdentity,
      sourceDelegate: sourceDelegate,
      duration: duration,
      curve: curve,
      watchDestination: watchDestination,
      onStart: onStart,
      onEnd: onEnd,
    );
  }

  void startRoutePop(_MorphEndpointHandle endpoint) {
    final currentFlight = _flights[endpoint.tag];
    if (currentFlight != null && currentFlight.kind.isRoute) return;

    final destination = _candidateFor(
      endpoint,
      preferDifferentRoute: true,
      requireActive: true,
    );
    if (destination == null) return;

    if (endpoint.animationsDisabled || destination.animationsDisabled) {
      _transferOwnershipImmediately(destination);
      return;
    }

    final routeAnimation = endpoint.route?.animation;
    if (routeAnimation == null) {
      _transferOwnershipImmediately(destination);
      return;
    }
    if (currentFlight != null) {
      _retargetToRoutePop(
        currentFlight,
        destination,
        ReverseAnimation(routeAnimation),
      );
      return;
    }
    _startFlight(
      sourceHandle: endpoint,
      destinationHandle: destination,
      kind: MorphFlightKind.routePop,
      flightAnimation: ReverseAnimation(routeAnimation),
    );
  }

  void finish(
    _MorphActiveFlight flight, {
    required bool arrived,
    bool returned = false,
    bool deferNotification = false,
  }) {
    if (!identical(_flights[flight.tag], flight)) return;
    final winner = returned
        ? flight.destinationHandle
        : arrived
        ? flight.destinationHandle
        : flight.sourceHandle ?? flight.destinationHandle;
    if (arrived || returned) {
      flight.markCohortCompleted();
    }
    final cohortReady = _cohortIsReady(flight.cohort);
    if ((arrived || returned) &&
        flight.holdAtEndpoint(
          winner,
          arrived: arrived,
          returned: returned,
        )) {
      _claimOwnership(winner);
      _invokeCompletionCallbacks(
        flight,
        winner,
        arrived: arrived,
        returned: returned,
      );
      if (cohortReady) _scheduleReadyCohortRelease(flight.cohort);
      notifyListeners();
      return;
    }
    if ((arrived || returned) && !cohortReady) {
      flight.holdForCohort(
        arrived: arrived,
        returned: returned,
      );
      _claimOwnership(winner);
      _invokeCompletionCallbacks(
        flight,
        winner,
        arrived: arrived,
        returned: returned,
      );
      return;
    }
    if (cohortReady) _scheduleReadyCohortRelease(flight.cohort);
    if ((arrived || returned) &&
        flight.beginEndpointHandoff(
          winner: winner,
          arrived: arrived,
          returned: returned,
        )) {
      _claimOwnership(winner);
      _invokeCompletionCallbacks(
        flight,
        winner,
        arrived: arrived,
        returned: returned,
      );
      return;
    }

    _removeFlight(flight.tag);
    _claimOwnership(winner);
    flight.dispose();

    _removeExpiredEndpoints(flight.tag);
    final pendingEndpoint = _takePendingRouteEndpoint(flight.tag);
    if (pendingEndpoint != null && !identical(_owners[flight.tag], pendingEndpoint)) {
      _startIncoming(pendingEndpoint);
    }
    _removeOverlayWhenIdle();
    _invokeCompletionCallbacks(
      flight,
      winner,
      arrived: arrived,
      returned: returned,
    );
    if (!deferNotification) {
      notifyListeners();
      return;
    }
    scheduleMicrotask(() {
      if (_overlayEntry != null) notifyListeners();
    });
  }

  void _releaseHeldFlight(_MorphActiveFlight flight) {
    if (!identical(_flights[flight.tag], flight) || !flight.heldAtEndpoint) {
      return;
    }
    finish(
      flight,
      arrived: flight.heldArrived,
      returned: flight.heldReturned,
    );
  }

  void _releaseEndpointHandoff(_MorphActiveFlight flight) {
    if (!identical(_flights[flight.tag], flight)) return;
    finish(
      flight,
      arrived: flight.heldArrived,
      returned: flight.heldReturned,
    );
  }

  void _releaseCohortFlight(_MorphActiveFlight flight) {
    if (!identical(_flights[flight.tag], flight) || !flight.heldForCohort) {
      return;
    }
    flight.releaseCohortHold();
    finish(
      flight,
      arrived: flight.heldArrived,
      returned: flight.heldReturned,
    );
  }

  void _flightEnded(_MorphActiveFlight flight) {
    for (final sibling in _siblings) {
      if (sibling.tag == flight.tag) {
        sibling.detachFlight(flight);
      }
    }
    scheduleMicrotask(() {
      if (_cohortIsReady(flight.cohort)) {
        _releaseReadyCohort(flight.cohort);
      }
    });
  }

  bool _cohortIsReady(Object cohort) {
    for (final flight in _flights.values) {
      if (identical(flight.cohort, cohort) && flight.blocksCohortCompletion) {
        return false;
      }
    }
    return true;
  }

  void _scheduleReadyCohortRelease(Object cohort) {
    scheduleMicrotask(() => _releaseReadyCohort(cohort));
  }

  void _releaseReadyCohort(Object cohort) {
    if (!_cohortIsReady(cohort)) return;
    _flights.values
        .where(
          (flight) => identical(flight.cohort, cohort) && flight.heldForCohort,
        )
        .toList(growable: false)
        .forEach(_releaseCohortFlight);
  }

  void _invokeCompletionCallbacks(
    _MorphActiveFlight flight,
    _MorphEndpointHandle winner, {
    required bool arrived,
    required bool returned,
  }) {
    if ((!arrived && !returned) || flight._completionCallbacksInvoked) return;
    flight._completionCallbacksInvoked = true;
    _invokeCallback(
      tag: flight.tag,
      name: 'onReceived',
      callback: winner.onReceived,
    );
    _invokeCallback(
      tag: flight.tag,
      name: 'onEnd',
      callback: flight.onEnd,
    );
  }

  void cancelAfterStartFailure(_MorphActiveFlight flight) {
    if (!identical(_flights[flight.tag], flight)) return;
    _removeFlight(flight.tag);
    flight.cancelForRetarget();
    _claimOwnership(flight.destinationHandle);
    _removeExpiredEndpoints(flight.tag);
    _removeOverlayWhenIdle();
    _notifyListenersSafely();
  }

  void _startIncoming(_MorphEndpointHandle destination) {
    if (!destination.active || destination.disposed) {
      destination.visibility.hidden = false;
      return;
    }

    final source = _candidateFor(destination);
    if (source == null) {
      _claimOwnership(destination);
      return;
    }

    if (destination.animationsDisabled || source.animationsDisabled) {
      _transferOwnershipImmediately(destination);
      return;
    }

    final existingFlight = _flights[destination.tag];
    if (existingFlight != null) {
      if (existingFlight.kind.isRoute) {
        _pendingRouteEndpoints.putIfAbsent(destination.tag, () => []).add(destination);
        return;
      }
      _retarget(existingFlight, destination);
      return;
    }

    final destinationRoute = destination.route;
    final sourceRoute = source.route;
    if (!identical(destinationRoute, sourceRoute)) {
      final routeAnimation = destinationRoute?.animation;
      if (routeAnimation == null ||
          (!routeAnimation.status.isForwardOrCompleted || routeAnimation.status.isCompleted)) {
        _claimOwnership(destination);
        return;
      }
      _startFlight(
        sourceHandle: source,
        destinationHandle: destination,
        kind: MorphFlightKind.routePush,
        flightAnimation: _synchronizeRoutePushAnimation(routeAnimation),
      );
      return;
    }

    final controllerLease = _obtainSameFrameController(source.duration);
    _startFlight(
      sourceHandle: source,
      destinationHandle: destination,
      kind: MorphFlightKind.sameScreen,
      flightAnimation: controllerLease.controller,
      controllerLease: controllerLease,
    );
  }

  Animation<double> _synchronizeRoutePushAnimation(
    Animation<double> routeAnimation,
  ) {
    final initialProgress = routeAnimation.value;
    return routeAnimation.drive(
      Animatable<double>.fromCallback((progress) {
        final remainingProgress = 1 - initialProgress;
        if (remainingProgress <= 0) return 1;

        return ((progress - initialProgress) / remainingProgress).clamp(
          0.0,
          1.0,
        );
      }),
    );
  }

  void _retarget(
    _MorphActiveFlight current,
    _MorphEndpointHandle destination, {
    ({
      Duration duration,
      Curve curve,
      VoidCallback? onStart,
      VoidCallback? onEnd,
      Object destinationIdentity,
      bool watchDestination,
    })?
    configuration,
  }) {
    if (!_delegatesAreCompatible(
      current.delegate,
      destination.delegate,
    )) {
      _cancelFlightAndClaim(current, destination);
      _reportSkippedFlight(
        tag: destination.tag,
        reason: 'the retargeted endpoint delegate type is incompatible',
      );
      return;
    }

    final sourceRoute = current.destinationHandle.route;
    final destinationRoute = destination.route;
    final crossesRoutes = !identical(sourceRoute, destinationRoute);
    final routeAnimation = crossesRoutes ? destinationRoute?.animation : null;
    if (crossesRoutes && (routeAnimation == null || routeAnimation.status != AnimationStatus.forward)) {
      _cancelFlightAndClaim(current, destination);
      return;
    }

    final originIdentity = current.reversibleOriginIdentity;
    final returnsToDistinctOrigin =
        configuration == null &&
        current.sourceHandle != null &&
        originIdentity != null &&
        _endpointIdentity(destination) == originIdentity;
    final returnsToSameStateOrigin =
        configuration != null && originIdentity != null && configuration.destinationIdentity == originIdentity;
    if (!crossesRoutes &&
        current.kind == MorphFlightKind.sameScreen &&
        (returnsToDistinctOrigin || returnsToSameStateOrigin)) {
      _reverseToOrigin(
        current,
        destination,
        duration: configuration?.duration ?? current.destinationHandle.duration,
        curve: configuration?.curve ?? current.curve,
        watchDestination: configuration?.watchDestination ?? current.destinationHandle.watchDestination,
        onStart: configuration?.onStart ?? current.destinationHandle.onStart,
        onEnd: configuration?.onEnd ?? current.destinationHandle.onEnd,
      );
      return;
    }

    final sampledSource = current.sample();
    current.cancelForRetarget();
    _removeFlight(current.tag);

    final destinationProperties = _capture(
      destination,
      reuseSameFrame: true,
    );
    if (destinationProperties == null) {
      _claimOwnership(destination);
      _removeOverlayWhenIdle();
      return;
    }

    final _MorphControllerLease? controllerLease;
    final MorphFlightKind kind;
    final Animation<double> flightAnimation;
    if (routeAnimation != null) {
      controllerLease = null;
      kind = MorphFlightKind.routePush;
      flightAnimation = _synchronizeRoutePushAnimation(routeAnimation);
    } else {
      controllerLease = _obtainSameFrameController(
        configuration?.duration ?? current.destinationHandle.duration,
      );
      kind = MorphFlightKind.sameScreen;
      flightAnimation = controllerLease.controller;
    }
    final flight = _MorphActiveFlight(
      coordinator: this,
      tag: destination.tag,
      sourceHandle: current.destinationHandle,
      destinationHandle: destination,
      delegate: current.delegate,
      source: sampledSource,
      destination: destinationProperties,
      kind: kind,
      flightAnimation: flightAnimation,
      curve: configuration?.curve ?? current.destinationHandle.curve,
      watchDestination: configuration?.watchDestination ?? current.destinationHandle.watchDestination,
      onStart: configuration?.onStart ?? current.destinationHandle.onStart,
      onEnd: configuration?.onEnd ?? current.destinationHandle.onEnd,
      cohort: _obtainSameFrameCohort(),
      structuralOrder: current.structuralOrder,
      registrationOrder: current.registrationOrder,
      controllerLease: controllerLease,
    );
    current.destinationHandle.visibility.hidden = true;
    destination.visibility.hidden = true;
    _installFlight(flight);
    _ensureOverlay();
    notifyListeners();
    flight.start();
  }

  void _reverseToOrigin(
    _MorphActiveFlight current,
    _MorphEndpointHandle destination, {
    required Duration duration,
    required Curve curve,
    required bool watchDestination,
    required VoidCallback? onStart,
    required VoidCallback? onEnd,
  }) {
    final progress = current.flightAnimation.value.clamp(0.0, 1.0);
    if (progress <= 0) {
      _cancelFlightAndClaim(current, destination);
      return;
    }

    final currentOrigin = _capture(destination, reuseSameFrame: true);
    if (currentOrigin == null || !_sameGeometry(current.currentSource, currentOrigin)) {
      _retargetFromSample(
        current,
        destination,
        duration: duration,
        curve: curve,
        watchDestination: watchDestination,
        onStart: onStart,
        onEnd: onEnd,
        capturedDestination: currentOrigin,
      );
      return;
    }

    final controllerLease = _MorphControllerLease(
      vsync: overlay,
      duration: duration,
      initialValue: progress,
      startsInReverse: true,
    )..retain();
    current.cancelForRetarget();
    _removeFlight(current.tag);
    destination.visibility.hidden = true;
    final flight = _MorphActiveFlight(
      coordinator: this,
      tag: destination.tag,
      sourceHandle: current.sourceHandle,
      destinationHandle: destination,
      delegate: current.delegate,
      source: current.currentSource,
      destination: current.currentDestination,
      kind: MorphFlightKind.sameScreen,
      flightAnimation: controllerLease.controller,
      curve: current.curve,
      watchDestination: watchDestination,
      onStart: onStart,
      onEnd: onEnd,
      cohort: _obtainSameFrameCohort(),
      structuralOrder: current.structuralOrder,
      registrationOrder: current.registrationOrder,
      reversibleOriginIdentity: current.reversibleOriginIdentity,
      completesAtSource: true,
      controllerLease: controllerLease,
    );
    _installFlight(flight);
    _ensureOverlay();
    notifyListeners();
    flight.start();
  }

  void _retargetFromSample(
    _MorphActiveFlight current,
    _MorphEndpointHandle destination, {
    required Duration duration,
    required Curve curve,
    required bool watchDestination,
    required VoidCallback? onStart,
    required VoidCallback? onEnd,
    required MorphEndpoint<Object?>? capturedDestination,
  }) {
    final sampledSource = current.sample();
    current.cancelForRetarget();
    _removeFlight(current.tag);
    if (capturedDestination == null) {
      _claimOwnership(destination);
      _removeOverlayWhenIdle();
      return;
    }

    final controllerLease = _obtainSameFrameController(duration);
    final flight = _MorphActiveFlight(
      coordinator: this,
      tag: destination.tag,
      sourceHandle: current.destinationHandle,
      destinationHandle: destination,
      delegate: current.delegate,
      source: sampledSource,
      destination: capturedDestination,
      kind: MorphFlightKind.sameScreen,
      flightAnimation: controllerLease.controller,
      curve: curve,
      watchDestination: watchDestination,
      onStart: onStart,
      onEnd: onEnd,
      cohort: _obtainSameFrameCohort(),
      structuralOrder: current.structuralOrder,
      registrationOrder: current.registrationOrder,
      controllerLease: controllerLease,
    );
    current.destinationHandle.visibility.hidden = true;
    destination.visibility.hidden = true;
    _installFlight(flight);
    _ensureOverlay();
    notifyListeners();
    flight.start();
  }

  bool _sameGeometry(
    MorphEndpoint<Object?> source,
    MorphEndpoint<Object?> destination,
  ) {
    const tolerance = 0.001;
    bool close(double source, double destination) {
      return (source - destination).abs() <= tolerance;
    }

    if (!close(source.bounds.left, destination.bounds.left) ||
        !close(source.bounds.top, destination.bounds.top) ||
        !close(source.bounds.right, destination.bounds.right) ||
        !close(source.bounds.bottom, destination.bounds.bottom) ||
        !close(source.localSize.width, destination.localSize.width) ||
        !close(source.localSize.height, destination.localSize.height)) {
      return false;
    }
    for (var index = 0; index < 16; index += 1) {
      if (!close(
        source.transform.storage[index],
        destination.transform.storage[index],
      )) {
        return false;
      }
    }
    return true;
  }

  void _cancelFlightAndClaim(
    _MorphActiveFlight flight,
    _MorphEndpointHandle winner,
  ) {
    if (!identical(_flights[flight.tag], flight)) return;

    _removeFlight(flight.tag);
    flight.cancelForRetarget();
    _claimOwnership(winner);
    _removeExpiredEndpoints(flight.tag);
    _removeOverlayWhenIdle();
    notifyListeners();
  }

  void _transferOwnershipImmediately(
    _MorphEndpointHandle winner,
  ) {
    final current = _flights[winner.tag];
    if (current != null) {
      _removeFlight(winner.tag);
      current.cancelForRetarget();
    }
    _claimOwnership(winner);
    _removeExpiredEndpoints(winner.tag);
    _removeOverlayWhenIdle();
    if (_overlayEntry != null) {
      _notifyListenersSafely();
    }
  }

  void _notifyListenersSafely() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_notificationScheduled) return;
      _notificationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notificationScheduled = false;
        if (_overlayEntry != null) notifyListeners();
      });
      return;
    }
    notifyListeners();
  }

  void _retargetToRoutePop(
    _MorphActiveFlight current,
    _MorphEndpointHandle destination,
    Animation<double> flightAnimation,
  ) {
    if (!_delegatesAreCompatible(current.delegate, destination.delegate)) {
      _cancelFlightAndClaim(current, destination);
      _reportSkippedFlight(
        tag: destination.tag,
        reason: 'the retargeted endpoint delegate type is incompatible',
      );
      return;
    }

    final sampledSource = current.sample();
    final destinationProperties = _capture(destination);
    current.cancelForRetarget();
    _removeFlight(current.tag);
    if (destinationProperties == null) {
      _claimOwnership(destination);
      _removeOverlayWhenIdle();
      notifyListeners();
      return;
    }

    final flight = _MorphActiveFlight(
      coordinator: this,
      tag: destination.tag,
      sourceHandle: current.destinationHandle,
      destinationHandle: destination,
      delegate: current.delegate,
      source: sampledSource,
      destination: destinationProperties,
      kind: MorphFlightKind.routePop,
      flightAnimation: flightAnimation,
      curve: current.destinationHandle.curve,
      watchDestination: current.destinationHandle.watchDestination,
      onStart: current.destinationHandle.onStart,
      onEnd: current.destinationHandle.onEnd,
      cohort: _obtainSameFrameCohort(),
      structuralOrder: current.structuralOrder,
      registrationOrder: current.registrationOrder,
    );
    current.destinationHandle.visibility.hidden = true;
    destination.visibility.hidden = true;
    _installFlight(flight);
    _ensureOverlay();
    notifyListeners();
    flight.start();
  }

  void _startFlight({
    required _MorphEndpointHandle sourceHandle,
    required _MorphEndpointHandle destinationHandle,
    required MorphFlightKind kind,
    required Animation<double> flightAnimation,
    _MorphControllerLease? controllerLease,
  }) {
    if (!_delegatesAreCompatible(
      sourceHandle.delegate,
      destinationHandle.delegate,
    )) {
      _claimOwnership(destinationHandle);
      controllerLease?.release();
      _reportSkippedFlight(
        tag: sourceHandle.tag,
        reason: 'endpoint delegate types are incompatible',
      );
      return;
    }

    final source = _capture(sourceHandle);
    final destination = _capture(
      destinationHandle,
      reuseSameFrame: true,
    );
    if (source == null || destination == null) {
      _claimOwnership(destinationHandle);
      controllerLease?.release();
      _reportSkippedFlight(
        tag: sourceHandle.tag,
        reason: 'one or both endpoints did not have usable layout',
      );
      return;
    }

    sourceHandle.visibility.hidden = true;
    destinationHandle.visibility.hidden = true;
    final flight = _MorphActiveFlight(
      coordinator: this,
      tag: sourceHandle.tag,
      sourceHandle: sourceHandle,
      destinationHandle: destinationHandle,
      delegate: sourceHandle.delegate,
      source: source,
      destination: destination,
      kind: kind,
      flightAnimation: flightAnimation,
      curve: sourceHandle.curve,
      watchDestination: sourceHandle.watchDestination,
      onStart: sourceHandle.onStart,
      onEnd: sourceHandle.onEnd,
      cohort: _obtainSameFrameCohort(),
      structuralOrder: sourceHandle.structuralOrder ?? sourceHandle.registrationOrder,
      registrationOrder: sourceHandle.registrationOrder,
      reversibleOriginIdentity: kind == MorphFlightKind.sameScreen ? _endpointIdentity(sourceHandle) : null,
      controllerLease: controllerLease,
    );
    _installFlight(flight);
    _ensureOverlay();
    notifyListeners();
    flight.start();
  }

  bool _delegatesAreCompatible(
    MorphFlightDelegate<Object?> source,
    MorphFlightDelegate<Object?> destination,
  ) {
    return source.runtimeType == destination.runtimeType;
  }

  Object _endpointIdentity(_MorphEndpointHandle endpoint) {
    final child = endpoint.owner.widget.child;
    return child.key ?? child;
  }

  _MorphControllerLease _obtainSameFrameController(Duration duration) {
    final existing = _sameFrameControllers[duration];
    if (existing != null && !existing.isDisposed) {
      existing.retain();
      return existing;
    }

    final lease = _MorphControllerLease(vsync: overlay, duration: duration);
    _sameFrameControllers[duration] = lease;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(_sameFrameControllers[duration], lease)) {
        _sameFrameControllers.remove(duration);
      }
    });
    lease.retain();
    return lease;
  }

  Object _obtainSameFrameCohort() {
    final existing = _sameFrameCohort;
    if (existing != null) return existing;

    final cohort = Object();
    _sameFrameCohort = cohort;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(_sameFrameCohort, cohort)) {
        _sameFrameCohort = null;
      }
    });
    return cohort;
  }

  MorphEndpoint<Object?>? _capture(_MorphEndpointHandle endpoint, {bool reuseSameFrame = false}) {
    try {
      return endpoint.capture(reuseSameFrame: reuseSameFrame);
    } on Object catch (exception, stack) {
      _reportCaptureError(endpoint, exception, stack);
      return null;
    }
  }

  void _captureDeparture(_MorphEndpointHandle endpoint) {
    try {
      endpoint.captureDeparture();
    } on Object catch (exception, stack) {
      _reportCaptureError(endpoint, exception, stack);
    }
  }

  void _reportCaptureError(
    _MorphEndpointHandle endpoint,
    Object exception,
    StackTrace stack,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'oh_my_flutter Morph',
        context: ErrorDescription(
          'while capturing the Morph endpoint tagged ${endpoint.tag}',
        ),
      ),
    );
  }

  void _invokeCallback({
    required Object tag,
    required String name,
    required VoidCallback? callback,
  }) {
    if (callback == null) return;
    try {
      callback();
    } on Object catch (exception, stack) {
      reportCallbackError(
        tag: tag,
        callback: name,
        exception: exception,
        stack: stack,
      );
    }
  }

  void reportCallbackError({
    required Object tag,
    required String callback,
    required Object exception,
    required StackTrace stack,
  }) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'oh_my_flutter Morph',
        context: ErrorDescription(
          'while invoking Morph $callback for the flight tagged $tag',
        ),
      ),
    );
  }

  _MorphEndpointHandle? _candidateFor(
    _MorphEndpointHandle endpoint, {
    bool preferDifferentRoute = false,
    bool requireActive = false,
  }) {
    final endpoints = _endpoints[endpoint.tag];
    if (endpoints == null) return null;

    final owner = _owners[endpoint.tag];
    if (owner != null &&
        !identical(owner, endpoint) &&
        (!preferDifferentRoute || !identical(owner.route, endpoint.route)) &&
        (!requireActive || (owner.active && !owner.disposed)) &&
        (!owner.disposed || owner.cachedEndpoint != null)) {
      return owner;
    }

    _MorphEndpointHandle? fallback;
    for (final candidate in endpoints.reversed) {
      if (identical(candidate, endpoint) ||
          (requireActive && (!candidate.active || candidate.disposed)) ||
          (candidate.disposed && candidate.cachedEndpoint == null)) {
        continue;
      }
      fallback ??= candidate;
      if (preferDifferentRoute && !identical(candidate.route, endpoint.route)) {
        return candidate;
      }
      if (!preferDifferentRoute) return candidate;
    }
    return fallback;
  }

  void _scheduleEndpointPurge(
    _MorphEndpointHandle endpoint,
    int generation,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (endpoint.active || endpoint.retentionGeneration != generation) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (endpoint.active || endpoint.retentionGeneration != generation || _flightUses(endpoint)) {
          return;
        }
        _removeEndpoint(endpoint);
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
  }

  bool _flightUses(_MorphEndpointHandle endpoint) {
    final flight = _flights[endpoint.tag];
    return identical(flight?.sourceHandle, endpoint) || identical(flight?.destinationHandle, endpoint);
  }

  _MorphActiveFlight? _sharedAncestorFlight(_MorphActiveFlight descendant) {
    final sourceHandle = descendant.sourceHandle;
    if (sourceHandle == null) return null;

    final sourceAncestors = <_MorphActiveFlight>{};
    var ancestor = sourceHandle.parentEndpoint;
    while (ancestor != null) {
      final flight = _flights[ancestor.tag];
      if (flight != null && !identical(flight, descendant) && _flightUses(ancestor)) {
        sourceAncestors.add(flight);
      }
      ancestor = ancestor.parentEndpoint;
    }

    ancestor = descendant.destinationHandle.parentEndpoint;
    while (ancestor != null) {
      final flight = _flights[ancestor.tag];
      if (flight != null && sourceAncestors.contains(flight) && _flightUses(ancestor)) {
        return flight;
      }
      ancestor = ancestor.parentEndpoint;
    }
    return null;
  }

  void _removeExpiredEndpoints(Object tag) {
    final endpoints = _endpoints[tag];
    if (endpoints == null) return;
    final expired = <_MorphEndpointHandle>[];
    endpoints.removeWhere((endpoint) {
      final shouldRemove = !endpoint.active && !_flightUses(endpoint);
      if (shouldRemove) expired.add(endpoint);
      return shouldRemove;
    });
    _removePendingRouteEndpoints(tag, expired);
    final ownerWasRemoved = expired.contains(_owners[tag]);
    for (final endpoint in expired) {
      endpoint.visibility.dispose();
    }
    if (endpoints.isEmpty) {
      _endpoints.remove(tag);
      _owners.remove(tag);
      _pendingRouteEndpoints.remove(tag);
      return;
    }
    if (ownerWasRemoved) _claimOwnership(endpoints.last);
  }

  void _removeEndpoint(_MorphEndpointHandle endpoint) {
    final endpoints = _endpoints[endpoint.tag];
    endpoints?.remove(endpoint);
    _removePendingRouteEndpoints(endpoint.tag, [endpoint]);
    final wasOwner = identical(_owners[endpoint.tag], endpoint);
    if (endpoints?.isEmpty ?? false) {
      _endpoints.remove(endpoint.tag);
      _owners.remove(endpoint.tag);
      _pendingRouteEndpoints.remove(endpoint.tag);
    } else if (wasOwner) {
      _claimOwnership(endpoints!.last);
    }
    endpoint.visibility.hidden = false;
    endpoint.visibility.dispose();
  }

  _MorphEndpointHandle? _takePendingRouteEndpoint(Object tag) {
    final pending = _pendingRouteEndpoints.remove(tag);
    if (pending == null) return null;

    final endpoints = _endpoints[tag];
    if (endpoints == null) return null;
    for (final endpoint in pending.reversed) {
      if (endpoint.active && !endpoint.disposed && endpoints.contains(endpoint)) {
        return endpoint;
      }
    }
    return null;
  }

  void _removePendingRouteEndpoints(
    Object tag,
    Iterable<_MorphEndpointHandle> removed,
  ) {
    final pending = _pendingRouteEndpoints[tag];
    if (pending == null) return;

    pending.removeWhere(removed.contains);
    if (pending.isEmpty) _pendingRouteEndpoints.remove(tag);
  }

  void _claimOwnership(_MorphEndpointHandle winner) {
    final endpoints = _endpoints[winner.tag];
    if (endpoints == null || !endpoints.contains(winner)) return;

    _owners[winner.tag] = winner;
    for (final endpoint in endpoints) {
      endpoint.visibility.hidden = !identical(endpoint, winner);
    }
  }

  void _ensureOverlay() {
    if (_overlayEntry != null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => _MorphOverlay(this, entry));
    _overlayEntry = entry;
    overlay.insert(entry);
  }

  void _removeOverlayWhenIdle() {
    if (_flights.isNotEmpty) return;
    final entry = _overlayEntry;
    _overlayEntry = null;
    if (entry == null) return;
    entry
      ..remove()
      ..dispose();
  }

  void _reportSkippedFlight({
    required Object tag,
    required String reason,
  }) {
    assert(() {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError(
            'Morph skipped the flight tagged $tag because $reason.',
          ),
          library: 'oh_my_flutter Morph',
        ),
      );
      return true;
    }(), 'Morph debug diagnostics should report skipped flights.');
  }
}
