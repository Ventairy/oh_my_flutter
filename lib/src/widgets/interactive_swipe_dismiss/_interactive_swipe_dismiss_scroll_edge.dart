part of 'interactive_swipe_dismiss.dart';

final class _InteractiveSwipeDismissScrollEdge {
  bool wasAway = false;
  double peakDelta = 0;
  Timer? _cooldown;

  bool get isCoolingDown => _cooldown?.isActive ?? false;

  void track(double distance, double delta, {required bool isBallistic}) {
    if (distance > _InteractiveSwipeDismissState._scrollAwayThreshold) {
      wasAway = true;
      _cooldown?.cancel();
      peakDelta = 0;
      return;
    }
    if (!wasAway) return;
    if (delta.abs() > peakDelta) peakDelta = delta.abs();
    if (distance > _InteractiveSwipeDismissState._scrollEdgeTolerance) return;
    wasAway = false;
    if (isBallistic || peakDelta > _InteractiveSwipeDismissState._fastScrollDeltaThreshold) {
      _cooldown?.cancel();
      _cooldown = Timer(_InteractiveSwipeDismissState._flingCooldown, () {});
    }
    peakDelta = 0;
  }

  void reset() {
    wasAway = false;
    peakDelta = 0;
    _cooldown?.cancel();
    _cooldown = null;
  }
}
