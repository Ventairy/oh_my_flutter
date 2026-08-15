part of 'morph.dart';

class _MorphControllerLease {
  _MorphControllerLease({
    required TickerProvider vsync,
    required Duration duration,
    double initialValue = 0,
    this.startsInReverse = false,
  }) : controller = AnimationController(
         vsync: vsync,
         duration: duration,
         value: initialValue,
       );

  final AnimationController controller;
  final bool startsInReverse;
  int _users = 0;
  bool _started = false;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void retain() {
    _users += 1;
  }

  void start() {
    if (_started || _disposed) return;
    _started = true;
    unawaited(
      startsInReverse ? controller.reverse() : controller.forward(),
    );
  }

  void release() {
    if (_disposed) return;
    _users -= 1;
    if (_users > 0) return;
    _disposed = true;
    controller.dispose();
  }
}
