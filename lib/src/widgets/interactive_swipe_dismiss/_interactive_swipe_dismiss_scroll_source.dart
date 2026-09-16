part of 'interactive_swipe_dismiss.dart';

final class _InteractiveSwipeDismissScrollSource {
  _InteractiveSwipeDismissScrollSource({
    required this.scrollable,
    required this.position,
  });

  final ScrollableState scrollable;
  final ScrollPosition position;

  _InteractiveSwipeDismissScrollEdge minimumEdge = _InteractiveSwipeDismissScrollEdge();
  _InteractiveSwipeDismissScrollEdge maximumEdge = _InteractiveSwipeDismissScrollEdge();
  bool wasAwayFromEdge = false;
  double peakDelta = 0;
  Duration? flingReachedEdgeAt;
  double? frozenOffset;
  ScrollHoldController? hold;

  bool get isCurrent {
    return scrollable.mounted && identical(scrollable.position, position);
  }

  BuildContext? get notificationContext => scrollable.notificationContext;

  RenderObject? get renderObject => notificationContext?.findRenderObject();

  void resetMovement() {
    minimumEdge.reset();
    maximumEdge.reset();
    wasAwayFromEdge = false;
    peakDelta = 0;
    flingReachedEdgeAt = null;
  }

  void resetFreeze() {
    frozenOffset = null;
    hold = null;
  }
}
