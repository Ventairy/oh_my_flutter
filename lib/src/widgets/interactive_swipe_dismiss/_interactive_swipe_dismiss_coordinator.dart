part of 'interactive_swipe_dismiss.dart';

class _InteractiveSwipeDismissCoordinator {
  _InteractiveSwipeDismissCoordinator(this.state);

  final _InteractiveSwipeDismissState state;

  InteractiveSwipeDismissDirection get direction => state._effectiveDirection;

  double get activationDistance => _InteractiveSwipeDismissState._activationDistance;

  bool handlePointerDown(PointerDownEvent event) {
    return state._handlePointerDown(event, fromHandle: true);
  }

  void handleInitialPointerMove({
    required PointerMoveEvent event,
    required double accumulatedDx,
    required double accumulatedDy,
  }) {
    state._handlePointerMove(
      event,
      fromHandle: true,
      deltaDx: accumulatedDx,
      deltaDy: accumulatedDy,
    );
  }

  void handlePointerMove(PointerMoveEvent event) {
    state._handlePointerMove(event, fromHandle: true);
  }

  void handlePointerUp(PointerUpEvent event) {
    state._handlePointerUp(event, fromHandle: true);
  }

  void handlePointerCancel(PointerCancelEvent event) {
    state._handlePointerCancel(event, fromHandle: true);
  }

  void handleGestureRejected(int pointer) {
    state._handleHandleGestureRejected(pointer);
  }
}
