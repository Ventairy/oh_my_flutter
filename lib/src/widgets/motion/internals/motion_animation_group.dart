part of '../motion.dart';

/// Owns the animation channels for one [Motion] scheduler entry.
class _MotionAnimationGroup {
  static final _MotionScheduler _scheduler = _MotionScheduler.instance;

  final List<_MotionAnimation> animations = <_MotionAnimation>[];
  bool _muted = false;
  bool _forceFrames = false;
  bool _disposed = false;

  _MotionAnimationGroup? _schedulerPrevious;
  _MotionAnimationGroup? _schedulerNext;
  bool _schedulerLinked = false;

  bool get forceFrames => _forceFrames;
  set forceFrames(bool value) {
    if (_forceFrames == value) {
      return;
    }
    final oldValue = _forceFrames;
    _forceFrames = value;
    if (_schedulerLinked) {
      _scheduler.updateForceFrames(oldValue: oldValue, newValue: value);
    }
  }

  bool get muted => _muted;
  set muted(bool value) {
    if (_muted == value) {
      return;
    }
    _muted = value;
    updateScheduling();
  }

  void add(_MotionAnimation animation) {
    animations.add(animation);
  }

  void remove(_MotionAnimation animation) {
    animations.remove(animation);
    updateScheduling();
  }

  void updateScheduling() {
    if (_disposed || _muted || !_hasRunningAnimation) {
      _scheduler.remove(this);
      return;
    }
    _scheduler.add(this);
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _scheduler.remove(this);
    animations.clear();
  }

  void _tick(Duration timeStamp) {
    if (_disposed || _muted) {
      return;
    }
    for (var index = 0; index < animations.length; index += 1) {
      animations[index]._tick(timeStamp);
    }
    updateScheduling();
  }

  bool get _hasRunningAnimation {
    for (var index = 0; index < animations.length; index += 1) {
      if (animations[index]._isRunning) {
        return true;
      }
    }
    return false;
  }
}
