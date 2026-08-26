part of 'skeleton.dart';

class _SkeletonAnimationClock {
  _SkeletonAnimationClock._();

  static final _SkeletonAnimationClock instance = _SkeletonAnimationClock._();

  final Set<VoidCallback> _listeners = <VoidCallback>{};
  final Set<VoidCallback> _forcedListeners = <VoidCallback>{};
  late final Ticker _ticker = Ticker(_handleTick);

  Duration _accumulated = Duration.zero;
  Duration _elapsed = Duration.zero;

  Duration get elapsed => _elapsed;

  void addListener(VoidCallback listener, {required bool forceFrames}) {
    final wasEmpty = _listeners.isEmpty;
    _listeners.add(listener);
    if (forceFrames) {
      _forcedListeners.add(listener);
    } else {
      _forcedListeners.remove(listener);
    }
    _ticker.forceFrames = _forcedListeners.isNotEmpty;
    if (wasEmpty) _ticker.start();
  }

  void removeListener(VoidCallback listener) {
    if (!_listeners.remove(listener)) return;
    _forcedListeners.remove(listener);
    _ticker.forceFrames = _forcedListeners.isNotEmpty;
    if (_listeners.isNotEmpty) return;
    _ticker.stop(canceled: false);
    _accumulated = _elapsed;
    _SkeletonEffectFrameCache.instance.clear();
  }

  void _handleTick(Duration elapsed) {
    _elapsed = _accumulated + elapsed;
    _SkeletonEffectFrameCache.instance.beginFrame();
    for (final listener in _listeners) {
      listener();
    }
  }
}
