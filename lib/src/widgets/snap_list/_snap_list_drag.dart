part of 'snap_list.dart';

class _SnapListDrag implements Drag {
  new(this.delegate, this.motion);
  final Drag delegate;
  final _SnapListMotion motion;

  @override
  void update(DragUpdateDetails details) => delegate.update(details);

  @override
  void end(DragEndDetails details) => delegate.end(details);

  @override
  void cancel() {
    final wasDragging = motion.dragging;
    motion.dragging = false;
    delegate.cancel();
    if (wasDragging) motion.cancelDrag();
  }
}
