part of 'snap_list.dart';

class _SnapListPosition extends ScrollPositionWithSingleContext {
  new({required super.physics, required super.context, required this.motion, super.oldPosition})
    : super(keepScrollOffset: false) {
    motion.scroll = this;
    addListener(motion.changed);
  }

  final _SnapListMotion motion;

  void movePixels(double value) => forcePixels(value);

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) =>
      super.applyContentDimensions(0, motion.maxExtent);

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    motion.beginDrag();
    return _SnapListDrag(super.drag(details, dragCancelCallback), motion);
  }

  @override
  void applyUserOffset(double delta) {
    final destination = (pixels - delta).clamp(motion.dragMin, motion.dragMax);
    if (destination == pixels) return;
    motion.userMoved();
    // Reduced motion keeps gesture thresholds while suppressing interpolation
    // through the viewport's paint offset; the selected anchor stays visible.
    super.applyUserOffset(pixels - destination);
  }

  @override
  void goBallistic(double velocity) {
    if (motion.dragging) {
      motion.release(velocity);
      return;
    }
    super.goBallistic(0);
  }

  @override
  Future<void> moveTo(double to, {Duration? duration, Curve? curve, bool? clamp = true}) async {
    if (to == pixels) return;
    await motion.navigate(to > pixels ? 1 : -1);
  }

  @override
  void pointerScroll(double delta) => motion.wheel(delta);

  @override
  void dispose() {
    removeListener(motion.changed);
    if (identical(motion.scroll, this)) motion.scroll = null;
    super.dispose();
  }
}
