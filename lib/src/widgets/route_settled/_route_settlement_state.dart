part of 'route_settled.dart';

mixin _RouteSettlementState<T extends StatefulWidget> on State<T> {
  Animation<double>? _routeAnimation;
  Animation<double>? _secondaryRouteAnimation;
  ValueListenable<bool>? _gestureNotifier;
  bool _isRouteSettled = false;
  bool _routeIsCurrent = true;
  bool _waitingForSecondaryDismissal = false;

  void onRouteSettlementChanged({required bool settled});

  void _updateSettlement() {
    final routeAnimation = _routeAnimation;
    if (routeAnimation == null) return;

    final secondaryRouteSettled = _secondaryRouteAnimation?.status.isDismissed ?? true;
    final settled =
        routeAnimation.status.isCompleted &&
        secondaryRouteSettled &&
        _routeIsCurrent &&
        !_waitingForSecondaryDismissal &&
        !(_gestureNotifier?.value ?? false);
    if (settled == _isRouteSettled) return;

    _isRouteSettled = settled;
    onRouteSettlementChanged(settled: settled);
  }

  void _handleStatusChanged(AnimationStatus status) => _updateSettlement();

  void _handleSecondaryStatusChanged(AnimationStatus status) {
    if (!status.isDismissed) {
      _waitingForSecondaryDismissal = true;
    } else if (_routeIsCurrent) {
      _waitingForSecondaryDismissal = false;
    }
    _updateSettlement();
  }

  void _handleRouteBecameCurrent() {
    if (!mounted || !_routeIsCurrent) return;
    if (_secondaryRouteAnimation?.status.isDismissed ?? true) {
      _waitingForSecondaryDismissal = false;
    }
    _updateSettlement();
  }

  void _handleGestureChanged() => _updateSettlement();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    final wasCurrent = _routeIsCurrent;
    _routeIsCurrent = route?.isCurrent ?? true;
    if (!_routeIsCurrent) {
      _waitingForSecondaryDismissal = true;
    } else if (!wasCurrent && _waitingForSecondaryDismissal) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleRouteBecameCurrent());
    }
    if (_routeAnimation != null) {
      _updateSettlement();
      return;
    }

    if (route == null) {
      if (!_isRouteSettled) {
        _isRouteSettled = true;
        onRouteSettlementChanged(settled: true);
      }
      return;
    }

    _routeAnimation = route.animation;
    _routeAnimation?.addStatusListener(_handleStatusChanged);
    _secondaryRouteAnimation = route.secondaryAnimation;
    _secondaryRouteAnimation?.addStatusListener(_handleSecondaryStatusChanged);

    final navigator = Navigator.maybeOf(context);
    if (navigator != null) {
      _gestureNotifier = navigator.userGestureInProgressNotifier;
      _gestureNotifier?.addListener(_handleGestureChanged);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateSettlement();
    });
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleStatusChanged);
    _secondaryRouteAnimation?.removeStatusListener(_handleSecondaryStatusChanged);
    _gestureNotifier?.removeListener(_handleGestureChanged);
    super.dispose();
  }
}
