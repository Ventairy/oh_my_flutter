part of 'snap_list.dart';

class _SnapListNestedScroll {
  new(this.motion);
  final _SnapListMotion motion;
  AxisDirection direction = AxisDirection.down;
  int? _pointer;
  ScrollPosition? _child;
  ScrollHoldController? _hold;
  bool _transferred = false;
  VelocityTracker? _velocity;
  Offset _panOrigin = Offset.zero;

  Axis get axis => axisDirectionToAxis(direction);
  double get _sign => axisDirectionIsReversed(direction) ? -1 : 1;
  double _component(Offset offset) => axis == Axis.vertical ? offset.dy : offset.dx;

  void down(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _velocity = VelocityTracker.withKind(event.kind)..addPosition(event.timeStamp, event.position);
  }

  bool notification(ScrollNotification event) {
    if (_pointer == null || event.metrics.axis != axis || event.context == null) return false;
    final position = Scrollable.maybeOf(event.context!)?.position;
    if (position == null || identical(position, motion.scroll)) return false;
    if (event is ScrollStartNotification && event.dragDetails != null && !_transferred) _child = position;
    return false;
  }

  void move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _velocity?.addPosition(event.timeStamp, event.position);
    _move(event.delta);
  }

  void panStart(PointerPanZoomStartEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _panOrigin = event.position;
    _velocity = VelocityTracker.withKind(event.kind)..addPosition(event.timeStamp, event.position);
  }

  void panUpdate(PointerPanZoomUpdateEvent event) {
    if (event.pointer != _pointer) return;
    _velocity?.addPosition(event.timeStamp, _panOrigin + event.pan);
    _move(event.panDelta);
  }

  void _move(Offset movement) {
    final child = _child;
    if (child == null) return;
    var delta = -_component(movement) * _sign;
    if (!_transferred) {
      final perpendicular = axis == Axis.vertical ? movement.dx : movement.dy;
      if (delta.abs() <= perpendicular.abs()) return;
      // Compare physical movement with the descendant's own direction, which
      // can differ from the list (for example, a reversed chat scrollable).
      final childDelta = -_component(movement) * (axisDirectionIsReversed(child.axisDirection) ? -1 : 1);
      final remaining = childDelta > 0
          ? math.max(0, child.maxScrollExtent - child.pixels)
          : math.max(0, child.pixels - child.minScrollExtent);
      final atEdge = childDelta.abs() > remaining;
      final hasTarget = delta > 0 ? motion.pixels < motion.maxExtent : motion.pixels > 0;
      if (!atEdge || !hasTarget) return;
      child.jumpTo(childDelta > 0 ? child.maxScrollExtent : child.minScrollExtent);
      delta = delta.sign * math.max(0.0, delta.abs() - remaining);
      _hold = child.hold(() {});
      motion.beginDrag();
      _transferred = true;
    }
    final destination = (motion.pixels + delta).clamp(motion.dragMin, motion.dragMax);
    if (destination == motion.pixels) return;
    motion.userMoved();
    motion.scroll?.movePixels(destination);
  }

  void up(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (_transferred || (event is PointerCancelEvent && motion.dragging)) {
      if (event is PointerCancelEvent) {
        motion.cancelDrag();
      } else {
        final speed = _velocity?.getVelocity().pixelsPerSecond ?? Offset.zero;
        motion.release(-_component(speed) * _sign);
      }
    }
    clear();
  }

  void clear() {
    _hold?.cancel();
    _hold = null;
    _child = null;
    _pointer = null;
    _velocity = null;
    _transferred = false;
  }
}
