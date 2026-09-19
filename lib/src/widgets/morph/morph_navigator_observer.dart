part of 'morph.dart';

/// Enables Morph transitions between the routes of a Navigator.
///
/// Create one observer in the State that owns your Navigator and include it in
/// the Navigator's observers from its first build. Use a separate observer for
/// each nested Navigator. Keep the instance across rebuilds.
///
/// Routes without matching content interrupt the shared-element relationship;
/// Morph only transitions between the two routes involved in navigation.
///
/// See the [Morph guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph.md)
/// for Navigator and router setup.
class MorphNavigatorObserver extends NavigatorObserver {
  /// Creates an observer for one Navigator containing Morph appearances.
  new();

  final List<WeakReference<_MorphCoordinator>> _coordinators = [];
  Route<Object?>? _currentRoute;
  Route<Object?>? _returningRoute;
  Route<Object?>? _arrivingRoute;
  _MorphNavigationRequest? _request;
  int _revision = 0;
  WeakReference<NavigatorState>? _initialNavigator;
  ModalRoute<Object?>? _gestureRoute;
  Route<Object?>? _gestureDestination;
  double _gestureStart = 1;
  double _gestureValue = 1;
  double _gestureDelta = 0;
  AnimationStatus _gestureStatus = AnimationStatus.completed;
  bool _gestureMoved = false;

  final List<WeakReference<_MorphTagStatusListenable>> _tagStatusListeners = [];
  final Set<_MorphTagStatusListenable> _subscribedTagStatuses = {};
  final Map<Object, MorphTagStatus> _tagStatuses = {};
  final Map<Object, WeakReference<_MorphActiveFlight>> _tagFlights = {};
  bool _tagResolutionPending = false;
  bool _tagNotificationScheduled = false;

  /// Finds the Morph observer installed on [navigator], including subclasses.
  ///
  /// Returns null when none is installed. Each Navigator needs its own stable
  /// observer from creation; nested Navigators do not inherit an outer observer.
  static MorphNavigatorObserver? maybeOfNavigator(NavigatorState navigator) {
    final observers = navigator.widget.observers.whereType<MorphNavigatorObserver>().toList(growable: false);
    assert(observers.length <= 1, 'A Navigator must not have multiple MorphNavigatorObservers.');
    return observers.length == 1 ? observers.single : null;
  }

  /// Reads or watches the given [tag] status
  ///
  /// Read `.value` for the current status, or add a listener for changes. Remove
  /// listeners when no longer needed; do not dispose the returned listenable.
  /// Equal tags share a status on this observer. Queries do not start flights.
  ///
  /// Status follows the latest navigation on this Navigator. It starts at
  /// [MorphTagStatus.idle], becomes pending during resolution, then reports an
  /// unmatched result or the accepted flight's lifecycle. Terminal results stay
  /// available until the next navigation. Local appearance changes are excluded.
  /// Endpoints must be available during the destination's initial layout.
  ///
  /// Only unmatched selects a fallback; completion and cancellation must not
  /// start another entrance or exit animation. Honor reduced motion separately.
  /// See the [Morph guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph.md).
  ValueListenable<MorphTagStatus> tagStatus(Object tag) {
    _tagStatusListeners.removeWhere((reference) => reference.target == null);
    for (final reference in _tagStatusListeners) {
      final listenable = reference.target;
      if (listenable != null && listenable.tag == tag) return listenable;
    }
    final listenable = _MorphTagStatusListenable(this, tag);
    _tagStatusListeners.add(WeakReference(listenable));
    return listenable;
  }

  MorphTagStatus _tagStatusValue(Object tag) =>
      _tagStatuses[tag] ??
      (_request == null
          ? MorphTagStatus.idle
          : _tagResolutionPending
          ? MorphTagStatus.pending
          : MorphTagStatus.unmatched);

  void _notifyTagStatus() {
    if (_tagNotificationScheduled) return;
    _tagNotificationScheduled = true;
    scheduleMicrotask(() {
      _tagNotificationScheduled = false;
      _tagStatusListeners.removeWhere((reference) => reference.target == null);
      for (final reference in List.of(_tagStatusListeners)) {
        reference.target?.update();
      }
    });
  }

  void _beginTagResolution() {
    _tagStatuses.clear();
    _tagFlights.clear();
    _tagResolutionPending = true;
    _notifyTagStatus();
    final revision = _revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Coordinator reconciliation runs in post-frame microtasks, including
      // coordinators first registered by the destination in this frame.
      scheduleMicrotask(
        () => scheduleMicrotask(() {
          if (_revision != revision) return;
          _tagResolutionPending = false;
          _notifyTagStatus();
        }),
      );
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _acceptTagFlight(_MorphActiveFlight flight) {
    final request = _request;
    if (request == null || !flight.kind.isRoute || request.cancelled) return;
    final source = flight.sourceHandle?.route;
    final destination = flight.destinationHandle.route;
    final connectsRoutes =
        (identical(source, request.source) && identical(destination, request.destination)) ||
        (identical(source, request.destination) && identical(destination, request.source));
    if (!connectsRoutes || flight._finished) return;
    _tagFlights[flight.tag] = WeakReference(flight);
    _tagStatuses[flight.tag] = MorphTagStatus.flying;
    _notifyTagStatus();
  }

  void _completeTagFlight(_MorphActiveFlight flight, _MorphEndpointHandle winner) {
    if (!identical(_tagFlights[flight.tag]?.target, flight)) return;
    _tagFlights.remove(flight.tag);
    _tagStatuses[flight.tag] = _request?.cancelled != true && identical(winner.route, _request?.destination)
        ? MorphTagStatus.completed
        : MorphTagStatus.cancelled;
    _notifyTagStatus();
  }

  void _endTagFlight(_MorphActiveFlight flight) {
    // Retargeting can replace the flight synchronously. Only cancel if no new
    // flight has taken its place for this navigation.
    scheduleMicrotask(() {
      if (!identical(_tagFlights[flight.tag]?.target, flight)) return;
      _tagFlights.remove(flight.tag);
      _tagStatuses[flight.tag] = MorphTagStatus.cancelled;
      _notifyTagStatus();
    });
  }

  static MorphNavigatorObserver? _of(BuildContext context) {
    final owner = Navigator.maybeOf(context);
    if (owner == null) return null;
    final observers = owner.widget.observers.whereType<MorphNavigatorObserver>().toList(growable: false);
    assert(
      observers.length == 1,
      'A Navigator containing Morph must have exactly one stable MorphNavigatorObserver '
      'in its observers from Navigator creation. Each nested Navigator needs its own observer.',
    );
    if (observers.length != 1) return null;
    final observer = observers.single;
    assert(
      identical(observer.navigator, owner) && identical(observer._initialNavigator?.target, owner),
      'MorphNavigatorObserver must observe the actual owning Navigator from its creation. '
      'Do not share an observer between Navigators or add it after the Navigator has mounted. '
      'Observer subclasses must call super in overridden callbacks.',
    );
    return observer;
  }

  void _register(_MorphCoordinator coordinator) {
    _coordinators.removeWhere((reference) => reference.target == null);
    if (_coordinators.any((reference) => identical(reference.target, coordinator))) return;
    _coordinators.add(WeakReference(coordinator));
  }

  void _notify() {
    _coordinators.removeWhere((reference) => reference.target == null);
    for (final reference in _coordinators) {
      reference.target?._navigationChanged(this);
    }
  }

  bool _owns(Route<Object?> route) => navigator != null && identical(route.navigator, navigator);

  @override
  @mustCallSuper
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    if (!_owns(route)) return;
    assert(() {
      if (previousRoute == null) _initialNavigator = WeakReference(navigator!);
      return true;
    }(), 'Record the Navigator observed from its creation.');
    _arrivingRoute = route;
  }

  @override
  @mustCallSuper
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) {
    if (identical(route, _currentRoute)) _returningRoute = route;
  }

  @override
  @mustCallSuper
  void didRemove(Route<Object?> route, Route<Object?>? previousRoute) {
    if (identical(route, _currentRoute)) _returningRoute = route;
  }

  @override
  @mustCallSuper
  void didReplace({Route<Object?>? newRoute, Route<Object?>? oldRoute}) {
    if (identical(oldRoute, _currentRoute)) _arrivingRoute = newRoute;
  }

  @override
  @mustCallSuper
  void didChangeTop(Route<Object?> topRoute, Route<Object?>? previousTopRoute) {
    if (!_owns(topRoute)) return;
    final kind = !identical(topRoute, _arrivingRoute) && identical(previousTopRoute, _returningRoute)
        ? MorphFlightKind.routePop
        : MorphFlightKind.routePush;
    _returningRoute = null;
    _arrivingRoute = null;
    _currentRoute = topRoute;
    if (_request case final request?
        when _gestureMoved && identical(request.source, previousTopRoute) && identical(request.destination, topRoute)) {
      request.preview = false;
      return;
    }
    _request = _MorphNavigationRequest(
      source: previousTopRoute,
      destination: topRoute,
      kind: kind,
      revision: ++_revision,
    );
    _beginTagResolution();
    _notify();
  }

  @override
  @mustCallSuper
  void didStartUserGesture(Route<Object?> route, Route<Object?>? previousRoute) {
    if (!_owns(route) || route is! ModalRoute<Object?> || previousRoute == null) return;
    _clearGesture();
    _gestureRoute = route;
    _gestureDestination = previousRoute;
    _gestureStart = route.animation?.value ?? 1;
    _gestureValue = _gestureStart;
    _gestureDelta = 0;
    _gestureStatus = route.animation?.status ?? AnimationStatus.completed;
    route.animation
      ?..addListener(_gestureChanged)
      ..addStatusListener(_gestureStatusChanged);
  }

  void _gestureChanged({bool reversing = false}) {
    final route = _gestureRoute;
    if (route == null) return;
    final value = route.animation?.value ?? _gestureValue;
    _gestureDelta = value - _gestureValue;
    _gestureValue = value;
    if (_gestureMoved) {
      if (_gestureDelta > 0 && identical(_currentRoute, route)) _cancelPreview();
      if (_gestureDelta < 0) _resumePreview();
      return;
    }
    if (!reversing && value == _gestureStart) return;
    _gestureMoved = true;
    _request = _MorphNavigationRequest(
      source: route,
      destination: _gestureDestination!,
      kind: MorphFlightKind.routePop,
      revision: ++_revision,
      preview: true,
    );
    _beginTagResolution();
    _notify();
  }

  void _resumePreview() {
    final request = _request;
    if (!_gestureMoved || request == null || !request.preview || !request.cancelled) return;
    request
      ..cancelled = false
      ..revision = ++_revision;
    _beginTagResolution();
    _notify();
  }

  void _gestureStatusChanged(AnimationStatus status) {
    final previous = _gestureStatus;
    _gestureStatus = status;
    if (status == AnimationStatus.reverse) {
      _resumePreview();
      _gestureChanged(reversing: true);
    }
    if ((!status.isCompleted && !(status == AnimationStatus.forward && previous == AnimationStatus.reverse)) ||
        !_gestureMoved ||
        !identical(_currentRoute, _gestureRoute)) {
      return;
    }
    _cancelPreview();
  }

  void _cancelPreview() {
    final request = _request;
    if (request == null || !request.preview || request.cancelled) return;
    request
      ..cancelled = true
      ..revision = ++_revision;
    _tagResolutionPending = false;
    _notifyTagStatus();
    _notify();
  }

  @override
  @mustCallSuper
  void didStopUserGesture() {
    if (_gestureMoved && identical(_currentRoute, _gestureRoute)) _cancelPreview();
    _clearGesture();
  }

  void _clearGesture() {
    _gestureRoute?.animation
      ?..removeListener(_gestureChanged)
      ..removeStatusListener(_gestureStatusChanged);
    _gestureRoute = null;
    _gestureDestination = null;
    _gestureMoved = false;
  }
}
