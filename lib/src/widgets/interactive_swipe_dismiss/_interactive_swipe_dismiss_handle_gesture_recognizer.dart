part of 'interactive_swipe_dismiss.dart';

final class _InteractiveSwipeDismissHandleGestureRecognizer extends OneSequenceGestureRecognizer {
  _InteractiveSwipeDismissHandleGestureRecognizer({
    required this._coordinator,
    super.debugOwner,
  });

  _InteractiveSwipeDismissCoordinator _coordinator;
  _InteractiveSwipeDismissCoordinator? _gestureCoordinator;
  int? _pointer;
  InteractiveSwipeDismissDirection? _direction;
  double _accumulatedDx = 0;
  double _accumulatedDy = 0;
  bool _dismissalIntentAccepted = false;
  PointerEvent? _preRoutedMove;

  _InteractiveSwipeDismissCoordinator get _activeCoordinator {
    return _gestureCoordinator ?? _coordinator;
  }

  double get _signedPrimary {
    return switch (_direction!) {
      InteractiveSwipeDismissDirection.down => _accumulatedDy,
      InteractiveSwipeDismissDirection.up => -_accumulatedDy,
      InteractiveSwipeDismissDirection.left => -_accumulatedDx,
      InteractiveSwipeDismissDirection.right => _accumulatedDx,
    };
  }

  double get _crossAxis {
    return switch (_direction!) {
      InteractiveSwipeDismissDirection.down || InteractiveSwipeDismissDirection.up => _accumulatedDx,
      InteractiveSwipeDismissDirection.left || InteractiveSwipeDismissDirection.right => _accumulatedDy,
    };
  }

  bool get _hasDirectionalIntent {
    final primary = _signedPrimary;
    final cross = _crossAxis.abs();
    return primary >= _activeCoordinator.activationDistance && primary > cross;
  }

  bool get _shouldRejectDirection {
    final primary = _signedPrimary;
    final cross = _crossAxis.abs();
    return primary <= -_activeCoordinator.activationDistance ||
        (cross >= _activeCoordinator.activationDistance && cross >= primary.abs());
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final coordinator = _coordinator;
    if (_pointer != null || !coordinator.handlePointerDown(event)) return;
    _pointer = event.pointer;
    _gestureCoordinator = coordinator;
    _direction = coordinator.direction;
    _accumulatedDx = 0;
    _accumulatedDy = 0;
    _dismissalIntentAccepted = false;
    startTrackingPointer(event.pointer, event.transform);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (_pointer != event.pointer) return;
    switch (event) {
      case PointerMoveEvent():
        if (identical(_preRoutedMove, event.original ?? event)) {
          _preRoutedMove = null;
          return;
        }
        _handlePointerMove(event);
      case PointerUpEvent():
        _handlePointerUp(event);
      case PointerCancelEvent():
        _handlePointerCancel(event);
      case PointerEvent():
        return;
    }
  }

  void handleRawPointerMove(PointerMoveEvent event) {
    if (_pointer != event.pointer) return;
    _preRoutedMove = event.original ?? event;
    _handlePointerMove(event);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_dismissalIntentAccepted) {
      _activeCoordinator.handlePointerMove(event);
      return;
    }
    _accumulatedDx += event.delta.dx;
    _accumulatedDy += event.delta.dy;
    if (_hasDirectionalIntent) {
      _dismissalIntentAccepted = true;
      resolvePointer(event.pointer, GestureDisposition.accepted);
      if (_pointer != event.pointer) return;
      _activeCoordinator.handleInitialPointerMove(
        event: event,
        accumulatedDx: _accumulatedDx,
        accumulatedDy: _accumulatedDy,
      );
      return;
    }
    if (_shouldRejectDirection) _rejectPointer(event.pointer);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_dismissalIntentAccepted) {
      _activeCoordinator.handlePointerUp(event);
      _stopTracking(event.pointer);
      return;
    }
    _rejectPointer(event.pointer);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_dismissalIntentAccepted) {
      _activeCoordinator.handlePointerCancel(event);
      _stopTracking(event.pointer);
      return;
    }
    _rejectPointer(event.pointer);
  }

  void _rejectPointer(int pointer) {
    resolvePointer(pointer, GestureDisposition.rejected);
    if (_pointer == pointer) {
      _activeCoordinator.handleGestureRejected(pointer);
      _stopTracking(pointer);
    }
  }

  void _stopTracking(int pointer) {
    stopTrackingPointer(pointer);
    _pointer = null;
    _gestureCoordinator = null;
    _direction = null;
    _accumulatedDx = 0;
    _accumulatedDy = 0;
    _dismissalIntentAccepted = false;
    _preRoutedMove = null;
  }

  @override
  void rejectGesture(int pointer) {
    if (_pointer != pointer) return;
    _activeCoordinator.handleGestureRejected(pointer);
    _stopTracking(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'interactive swipe dismiss handle';

  @override
  void dispose() {
    final pointer = _pointer;
    if (pointer != null) {
      _activeCoordinator.handleGestureRejected(pointer);
      _pointer = null;
      _gestureCoordinator = null;
      _direction = null;
    }
    super.dispose();
  }
}
