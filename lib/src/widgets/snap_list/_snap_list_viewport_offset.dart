part of 'snap_list.dart';

class _SnapListViewportOffset extends ViewportOffset {
  new(this.motion, this.position) {
    motion.addListener(notifyListeners);
    position.addListener(notifyListeners);
  }
  final _SnapListMotion motion;
  final ViewportOffset position;

  @override
  double get pixels => motion.displayPixels;
  @override
  bool get hasPixels => position.hasPixels;
  @override
  bool get allowImplicitScrolling => false;
  @override
  ScrollDirection get userScrollDirection => position.userScrollDirection;
  @override
  bool applyViewportDimension(double viewportDimension) => position.applyViewportDimension(viewportDimension);
  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) =>
      position.applyContentDimensions(minScrollExtent, maxScrollExtent);
  @override
  void correctBy(double correction) => position.correctBy(correction);
  @override
  void jumpTo(double pixels) => position.jumpTo(pixels);
  @override
  Future<void> animateTo(double to, {required Duration duration, required Curve curve}) =>
      position.animateTo(to, duration: duration, curve: curve);
  @override
  void dispose() {
    motion.removeListener(notifyListeners);
    position.removeListener(notifyListeners);
    super.dispose();
  }
}
