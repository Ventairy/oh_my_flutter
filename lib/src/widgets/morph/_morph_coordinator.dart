part of 'morph.dart';

class _MorphCoordinator extends ChangeNotifier {
  _MorphCoordinator._(this.overlay);

  factory _MorphCoordinator.of(OverlayState overlay) {
    return _coordinators[overlay] ??= _MorphCoordinator._(overlay);
  }

  static final Expando<_MorphCoordinator> _coordinators = Expando<_MorphCoordinator>('oh_my_flutter.morph');

  final OverlayState overlay;
  final Map<Object, _MorphTargetGroup> _groups = {};
  final Set<_MorphTargetGroup> _pendingGroups = {};
  bool _reconciliationScheduled = false;
  final Map<Object, _MorphActiveFlight> _flights = {};
  final List<_MorphActiveFlight> _orderedFlights = [];
  final Set<_MorphEndpointHandle> _scheduledIncomingEndpoints = {};
  final List<_MorphSiblingHandle> _siblings = [];
  final List<_MorphSiblingHandle> _visibleSiblings = [];
  final Map<(Duration, Object?), _MorphControllerLease> _sameFrameControllers = {};
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
    for (var pass = 0; pass < 2; pass += 1) {
      for (final sibling in _siblings) {
        if (!sibling.active ||
            sibling.disposed ||
            !sibling.paintsOnTop ||
            !sibling.canPaint ||
            sibling.tag != flight.tag ||
            identical(sibling.target, flight.destinationHandle.target) != (pass == 1)) {
          continue;
        }
        if (_siblingParticipates(flight, sibling)) _visibleSiblings.add(sibling);
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
    final group = _groups[sibling.tag];
    if (group != null) _pruneGroup(group);
    if (_overlayEntry != null) _notifyListenersSafely();
  }

  bool showsSibling(_MorphSiblingHandle sibling) {
    if (!sibling.paintsOnTop || !sibling.canPaint) return false;
    final flight = _flights[sibling.tag];
    return flight != null && _siblingParticipates(flight, sibling);
  }

  bool _siblingParticipates(
    _MorphActiveFlight flight,
    _MorphSiblingHandle sibling,
  ) {
    return identical(flight.sourceHandle?.target, sibling.target) ||
        identical(flight.destinationHandle.target, sibling.target) ||
        (_groups[flight.tag]?.progress[sibling.target]?.participates ?? false);
  }

  bool _hasFlightUsingSibling(_MorphSiblingHandle sibling) {
    final flight = _flights[sibling.tag];
    return flight != null && _siblingParticipates(flight, sibling);
  }

  bool _hasProjectedFlightUsingSibling(_MorphSiblingHandle sibling) {
    return sibling.paintsOnTop && _hasFlightUsingSibling(sibling);
  }

  bool _hasScheduledIncomingFlightUsingSibling(
    _MorphSiblingHandle sibling,
  ) {
    if (!sibling.hasTransition) return false;
    for (final endpoint in _scheduledIncomingEndpoints) {
      if (identical(endpoint.target, sibling.target) && endpoint.active && !endpoint.disposed) {
        return true;
      }
    }
    return false;
  }

  void _prepareSiblingsForIncomingFlight(
    _MorphEndpointHandle destination,
  ) {
    for (final sibling in _siblings) {
      if (!sibling.active || sibling.disposed || !identical(sibling.target, destination.target)) {
        continue;
      }
      sibling.prepareForIncomingFlight();
    }
  }

  void _installFlight(_MorphActiveFlight flight) {
    flight.updateLandingNavigation(flight.kind.isRoute ? flight.destinationHandle.observer?._request : null);
    final group = _groups[flight.tag]!;
    if (flight.completesAtSource ||
        (flight.sourceHandle != null && !identical(flight.sourceHandle!.target, flight.destinationHandle.target))) {
      group.siblingTransition?.dispose();
      group.siblingTransition = _MorphSiblingTransition(group: group, coordinator: this, flight: flight);
    }
    final replaced = _flights[flight.tag];
    if (replaced != null) _orderedFlights.remove(replaced);
    _flights[flight.tag] = flight;
    var insertionIndex = 0;
    while (insertionIndex < _orderedFlights.length &&
        _compareFlightOrder(_orderedFlights[insertionIndex], flight) <= 0) {
      insertionIndex += 1;
    }
    _orderedFlights.insert(insertionIndex, flight);
    flight.destinationHandle.observer?._acceptTagFlight(flight);
    for (final sibling in _siblings) {
      if (!sibling.active || sibling.tag != flight.tag) continue;
      _attachSiblingFlight(sibling);
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
    final group = _groups.putIfAbsent(sibling.tag, () => _MorphTargetGroup(sibling.tag));
    final progress = group.progress.putIfAbsent(
      sibling.target,
      () => _MorphTargetProgress(group.selected == null || identical(group.selected?.target, sibling.target) ? 1 : 0),
    );
    final flight = _flights[sibling.tag];
    sibling.updateProgress(progress.curved, progress.uncurved);
    if (flight != null && _siblingParticipates(flight, sibling)) {
      sibling.attachFlight(flight, progress.curved, progress.uncurved);
    }
  }

  void _updateSiblingProgress(_MorphTargetGroup group) {
    for (final sibling in _siblings) {
      if (!sibling.active || sibling.disposed || sibling.tag != group.tag) continue;
      _attachSiblingFlight(sibling);
    }
  }

  void _settleSiblingProgress(_MorphTargetGroup group, MorphTarget? winner) {
    if (group.siblingTransition != null) return;
    for (final entry in group.progress.entries) {
      entry.value.settle(identical(entry.key, winner) ? 1 : 0);
    }
    _updateSiblingProgress(group);
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
    final group = _groups.putIfAbsent(endpoint.tag, () => _MorphTargetGroup(endpoint.tag));
    group
      ..register(endpoint)
      ..progress.putIfAbsent(endpoint.target, () => _MorphTargetProgress(group.selected == null ? 1 : 0));
    endpoint.observer?._register(this);
    _scheduleStructuralOrderRefresh();
    if (group.selected == null) {
      group.selected = endpoint;
      _claimOwnership(endpoint);
    } else if (!identical(group.selected!.target, endpoint.target)) {
      endpoint.visibility.hidden = true;
      _scheduledIncomingEndpoints.add(endpoint);
      _prepareSiblingsForIncomingFlight(endpoint);
    }
    _scheduleReconciliation(group);
  }

  void _scheduleReconciliation(_MorphTargetGroup group) {
    _pendingGroups.add(group);
    if (_reconciliationScheduled) return;
    _reconciliationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Navigator observers may schedule their own route preparation callbacks.
      // Resolve after all of them have restored the routes' actual animations.
      scheduleMicrotask(() {
        _reconciliationScheduled = false;
        final pending = _pendingGroups.toList(growable: false);
        _pendingGroups.clear();
        for (final group in pending) {
          if (identical(_groups[group.tag], group)) {
            _reconcile(group);
            final flight = _flights[group.tag];
            if (flight != null) flight.destinationHandle.observer?._acceptTagFlight(flight);
          }
        }
        _scheduledIncomingEndpoints.removeWhere(
          (endpoint) => !_pendingGroups.contains(_groups[endpoint.tag]),
        );
      });
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  _MorphEndpointHandle? _lastMounted(
    _MorphTargetGroup group,
    Route<Object?>? route, [
    Set<_MorphTargetGroup>? resolving,
  ]) {
    final ancestors = resolving ?? <_MorphTargetGroup>{};
    if (!ancestors.add(group)) return null;
    try {
      for (final endpoint in group.endpoints.reversed) {
        if (!endpoint.active || endpoint.disposed || !identical(endpoint.route, route)) continue;
        var parent = endpoint.parentEndpoint;
        var eligible = true;
        while (parent != null) {
          final parentGroup = _groups[parent.tag];
          if (!parent.active ||
              parent.disposed ||
              (parentGroup != null &&
                  !identical(parentGroup, group) &&
                  !identical(_lastMounted(parentGroup, route, ancestors)?.target, parent.target))) {
            eligible = false;
            break;
          }
          parent = parent.parentEndpoint;
        }
        if (eligible) return endpoint;
      }
      return null;
    } finally {
      ancestors.remove(group);
    }
  }

  void _navigationChanged(MorphNavigatorObserver observer) {
    for (final group in _groups.values) {
      if (group.endpoints.any((endpoint) => identical(endpoint.observer, observer))) {
        _scheduleReconciliation(group);
      }
    }
  }

  void _reconcile(_MorphTargetGroup group) {
    if (!overlay.mounted) return;
    final observer = group.endpoints.firstOrNull?.observer;
    final request = observer?._request;
    if (request != null && group.navigationRevision != request.revision) {
      group.navigationRevision = request.revision;
      if (request.cancelled) {
        final accepted = _lastMounted(group, request.source);
        group.selected = accepted;
        final current = _flights[group.tag];
        current?.updateLandingNavigation(null);
        if (current != null && current.hasIndependentClock) {
          if (current.kind == MorphFlightKind.routePush) {
            current.continueToDestination();
          } else {
            current.returnToSource();
          }
        } else if (current == null) {
          _settleUnmatchedNavigation(group, accepted);
        }
        return;
      }
      if (request.source != null) {
        final source =
            _lastMounted(group, request.source) ??
            (identical(group.selected?.route, request.source) ? group.selected : null);
        final destination = _lastMounted(group, request.destination);
        group.selected = destination;
        if (source != null && destination != null && request.source != null) {
          _startNavigation(source, destination, request);
        } else {
          _settleUnmatchedNavigation(group, destination);
        }
        return;
      }
    }
    final currentRoute = request != null && request.preview && !request.cancelled
        ? request.destination
        : observer?._currentRoute;
    final source = group.selected;
    final destination = _lastMounted(group, currentRoute);
    if (destination == null) {
      if (source != null && (!source.active || source.disposed)) {
        _settleUnmatchedNavigation(group, null);
      }
      return;
    }
    if (identical(source?.target, destination.target)) {
      group.selected = destination;
      if (!identical(source, destination) && _endpointIdentity(source!) != _endpointIdentity(destination)) {
        _startIncoming(destination, source: source);
      } else if (_flights[group.tag] == null) {
        _claimOwnership(destination);
      }
      return;
    }
    group.selected = destination;
    _scheduledIncomingEndpoints.remove(destination);
    if (source == null || !identical(source.route, destination.route)) {
      _transferOwnershipImmediately(destination);
      return;
    }
    _startIncoming(destination, source: source);
  }

  void _settleUnmatchedNavigation(_MorphTargetGroup group, _MorphEndpointHandle? destination) {
    final flight = _removeFlight(group.tag);
    flight?.cancelForRetarget();
    group
      ..selected = destination
      ..owner = destination
      ..siblingTransition?.dispose();
    _settleSiblingProgress(group, destination?.target);
    for (final endpoint in group.endpoints) {
      endpoint.visibility.hidden = !identical(endpoint, _lastMounted(group, endpoint.route));
    }
    _removeOverlayWhenIdle();
    if (_overlayEntry != null) _notifyListenersSafely();
  }

  void _startNavigation(
    _MorphEndpointHandle source,
    _MorphEndpointHandle destination,
    _MorphNavigationRequest request,
  ) {
    _flights[source.tag]?.updateLandingNavigation(request);
    if (request.kind == MorphFlightKind.routePush) {
      _startIncoming(destination, source: source);
      return;
    }
    final current = _flights[source.tag];
    if (source.configuredDuration == null &&
        !(current?.hasIndependentClock ?? false) &&
        !request.preview &&
        source.route?.animation?.status != AnimationStatus.reverse) {
      _transferOwnershipImmediately(destination);
      return;
    }
    if (current != null &&
        current.kind == MorphFlightKind.routePop &&
        identical(current.sourceHandle?.target, source.target) &&
        identical(current.destinationHandle.target, destination.target)) {
      if (current.hasIndependentClock) current.continueToDestination();
      return;
    }
    if (current != null &&
        current.kind == MorphFlightKind.routePush &&
        identical(current.sourceHandle?.target, destination.target) &&
        identical(current.destinationHandle.target, source.target)) {
      if (current.hasIndependentClock) current.returnToSource();
      return;
    }
    if (source.animationsDisabled || destination.animationsDisabled) {
      _transferOwnershipImmediately(destination);
      return;
    }
    if (current == null && (!source.flightsEnabled || !destination.flightsEnabled)) {
      _transferOwnershipImmediately(destination);
      return;
    }

    final configuredDuration = source.configuredDuration;
    final animation = source.route?.animation;
    if (configuredDuration == null && (animation == null || animation.isDismissed)) {
      _transferOwnershipImmediately(destination);
      return;
    }
    final controllerLease = configuredDuration == null
        ? null
        : _obtainSameFrameController(configuredDuration, group: source.route);
    final flightAnimation = controllerLease?.controller ?? ReverseAnimation(animation!);
    if (current != null) {
      _retargetToRoutePop(current, destination, flightAnimation, controllerLease: controllerLease);
    } else {
      _startFlight(
        sourceHandle: source,
        destinationHandle: destination,
        kind: MorphFlightKind.routePop,
        flightAnimation: flightAnimation,
        controllerLease: controllerLease,
      );
    }
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
    final group = _groups[endpoint.tag];
    if (group != null) _scheduleReconciliation(group);
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
    final group = _groups[endpoint.tag];
    if (group != null) _scheduleReconciliation(group);
  }

  void unregister(_MorphEndpointHandle endpoint) {
    endpoint
      ..active = false
      ..disposed = true
      ..retentionGeneration += 1;
    final group = _groups[endpoint.tag];
    if (group != null) _scheduleReconciliation(group);
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
    for (final group in _groups.values) {
      group.siblingTransition?.dispose();
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
    if (!identical(_groups[destination.tag]?.selected?.target, destination.target)) return;

    if (destination.animationsDisabled) {
      _transferOwnershipImmediately(destination);
      return;
    }

    if (_flights[destination.tag] == null && !destination.flightsEnabled) {
      _transferOwnershipImmediately(destination);
      return;
    }

    final structuralOrder = destination.structuralOrder ?? destination.registrationOrder;
    final registrationOrder = destination.registrationOrder;
    destination.visibility.hidden = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!destination.active || destination.disposed) return;
      if (!identical(_groups[destination.tag]?.selected?.target, destination.target)) return;

      if (_flights[destination.tag] == null && !destination.flightsEnabled) {
        _transferOwnershipImmediately(destination);
        return;
      }

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
    if (!identical(_groups[destination.tag]?.selected?.target, destination.target)) return;
    if (destination.animationsDisabled) {
      _transferOwnershipImmediately(destination);
      return;
    }
    if (_flights[destination.tag] == null && !destination.flightsEnabled) {
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
      _invokeCompletionCallbacks(
        flight,
        winner,
        arrived: arrived,
        returned: returned,
      );
      return;
    }
    if (cohortReady) _scheduleReadyCohortRelease(flight.cohort);
    if (flight.holdForDepartingRoute(winner, arrived: arrived, returned: returned)) {
      _invokeCompletionCallbacks(flight, winner, arrived: arrived, returned: returned);
      return;
    }
    if ((arrived || returned || flight.routeHandoffCompleted) &&
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

    flight.destinationHandle.observer?._completeTagFlight(flight, winner);
    _removeFlight(flight.tag);
    _claimOwnership(winner);
    flight.dispose();

    _removeExpiredEndpoints(flight.tag);
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
    flight.destinationHandle.observer?._endTagFlight(flight);
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
    _groups[flight.tag]?.siblingTransition?.dispose();
    _claimOwnership(flight.destinationHandle);
    _removeExpiredEndpoints(flight.tag);
    _removeOverlayWhenIdle();
    _notifyListenersSafely();
  }

  void _startIncoming(_MorphEndpointHandle destination, {_MorphEndpointHandle? source}) {
    if (!destination.active || destination.disposed) {
      destination.visibility.hidden = false;
      return;
    }

    source ??= _groups[destination.tag]?.selected;
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
      _retarget(existingFlight, destination);
      return;
    }

    if (!source.flightsEnabled || !destination.flightsEnabled) {
      _transferOwnershipImmediately(destination);
      return;
    }

    final destinationRoute = destination.route;
    final sourceRoute = source.route;
    if (!identical(destinationRoute, sourceRoute)) {
      final routeAnimation = destinationRoute?.animation;
      final configuredDuration = source.configuredDuration;
      if (configuredDuration != null && (routeAnimation == null || routeAnimation.status.isForwardOrCompleted)) {
        final controllerLease = _obtainSameFrameController(
          configuredDuration,
          group: destinationRoute,
        );
        _startFlight(
          sourceHandle: source,
          destinationHandle: destination,
          kind: MorphFlightKind.routePush,
          flightAnimation: controllerLease.controller,
          controllerLease: controllerLease,
        );
        return;
      }
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
    final configuredRouteDuration = crossesRoutes ? current.destinationHandle.configuredDuration : null;
    final canStartRouteFlight = configuredRouteDuration == null
        ? routeAnimation?.status == AnimationStatus.forward
        : routeAnimation == null || routeAnimation.status.isForwardOrCompleted;
    if (crossesRoutes && !canStartRouteFlight) {
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
    if (crossesRoutes) {
      kind = MorphFlightKind.routePush;
      if (configuredRouteDuration == null) {
        controllerLease = null;
        flightAnimation = _synchronizeRoutePushAnimation(routeAnimation!);
      } else {
        controllerLease = _obtainSameFrameController(
          configuredRouteDuration,
          group: destinationRoute,
        );
        flightAnimation = controllerLease.controller;
      }
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
    _groups[flight.tag]?.siblingTransition?.dispose();
    _claimOwnership(winner);
    _removeExpiredEndpoints(flight.tag);
    _removeOverlayWhenIdle();
    notifyListeners();
  }

  void _transferOwnershipImmediately(
    _MorphEndpointHandle winner,
  ) {
    _groups[winner.tag]?.siblingTransition?.dispose();
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
    Animation<double> flightAnimation, {
    _MorphControllerLease? controllerLease,
  }) {
    if (!_delegatesAreCompatible(current.delegate, destination.delegate)) {
      controllerLease?.release();
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
      controllerLease?.release();
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
      controllerLease: controllerLease,
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
    if (!sourceHandle.flightsEnabled || !destinationHandle.flightsEnabled) {
      _transferOwnershipImmediately(destinationHandle);
      controllerLease?.release();
      return;
    }

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
      if (!sourceHandle.captureFailed && !destinationHandle.captureFailed) {
        _reportSkippedFlight(
          tag: sourceHandle.tag,
          reason: 'one or both endpoints did not have usable layout',
        );
      }
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
    return (endpoint.target, endpoint.childIdentity);
  }

  _MorphControllerLease _obtainSameFrameController(
    Duration duration, {
    Object? group,
  }) {
    final key = (duration, group);
    final existing = _sameFrameControllers[key];
    if (existing != null && !existing.isDisposed) {
      existing.retain();
      return existing;
    }

    final lease = _MorphControllerLease(vsync: overlay, duration: duration);
    _sameFrameControllers[key] = lease;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(_sameFrameControllers[key], lease)) {
        _sameFrameControllers.remove(key);
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
      final captured = endpoint.capture(reuseSameFrame: reuseSameFrame);
      if (captured != null) endpoint.captureFailed = false;
      return captured;
    } on Object catch (exception, stack) {
      endpoint.captureFailed = true;
      _reportCaptureError(endpoint, exception, stack);
      return null;
    }
  }

  void _captureDeparture(_MorphEndpointHandle endpoint) {
    try {
      endpoint
        ..captureDeparture()
        ..captureFailed = false;
    } on Object catch (exception, stack) {
      endpoint.captureFailed = true;
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
    final endpoints = _groups[tag]?.endpoints;
    if (endpoints == null) return;
    final expired = <_MorphEndpointHandle>[];
    endpoints.removeWhere((endpoint) {
      final shouldRemove = !endpoint.active && !_flightUses(endpoint);
      if (shouldRemove) expired.add(endpoint);
      return shouldRemove;
    });
    final ownerWasRemoved = expired.contains(_groups[tag]?.owner);
    for (final endpoint in expired) {
      endpoint
        ..releaseDeparture()
        ..releaseGroupCache();
      endpoint.visibility.dispose();
    }
    final group = _groups[tag];
    if (group != null) _pruneGroup(group);
    if (ownerWasRemoved) {
      final group = _groups[tag];
      if (group != null) _scheduleReconciliation(group);
    }
  }

  void _removeEndpoint(_MorphEndpointHandle endpoint) {
    final endpoints = _groups[endpoint.tag]?.endpoints;
    endpoints?.remove(endpoint);
    final wasOwner = identical(_groups[endpoint.tag]?.owner, endpoint);
    final group = _groups[endpoint.tag];
    if (group != null) _pruneGroup(group);
    if (wasOwner) {
      final group = _groups[endpoint.tag];
      if (group != null) _scheduleReconciliation(group);
    }
    endpoint
      ..releaseDeparture()
      ..releaseGroupCache();
    endpoint.visibility.hidden = false;
    endpoint.visibility.dispose();
  }

  void _pruneGroup(_MorphTargetGroup group) {
    if (!group.endpoints.contains(group.owner)) group.owner = null;
    if (!group.endpoints.contains(group.selected)) group.selected = null;
    group.progress.removeWhere(
      (target, _) =>
          !group.endpoints.any((endpoint) => identical(endpoint.target, target)) &&
          !_siblings.any((sibling) => identical(sibling.target, target)),
    );
    if (group.endpoints.isNotEmpty || _flights.containsKey(group.tag)) return;
    group.siblingTransition?.dispose();
    if (_siblings.any((sibling) => sibling.tag == group.tag)) return;
    _pendingGroups.remove(group);
    _groups.remove(group.tag);
  }

  void _claimOwnership(_MorphEndpointHandle winner) {
    final endpoints = _groups[winner.tag]?.endpoints;
    if (endpoints == null || !endpoints.contains(winner)) return;

    final group = _groups[winner.tag];
    if (group == null) return;
    group.owner = winner;
    _settleSiblingProgress(group, winner.target);
    for (final endpoint in endpoints) {
      endpoint.visibility.hidden = !identical(endpoint, winner);
      if (endpoint.active && !_flightUses(endpoint)) endpoint.releaseDeparture();
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
