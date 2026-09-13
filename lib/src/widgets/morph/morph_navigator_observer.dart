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
  MorphNavigatorObserver();

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
    _notify();
  }

  void _resumePreview() {
    final request = _request;
    if (!_gestureMoved || request == null || !request.preview || !request.cancelled) return;
    request
      ..cancelled = false
      ..revision = ++_revision;
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
