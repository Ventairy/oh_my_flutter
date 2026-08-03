part of '../motion.dart';

/// Read-only animation driven by the shared motion scheduler.
class _MotionAnimation extends Animation<double> {
  _MotionAnimation(
    this._group,
    Duration duration,
    this._curve,
    this._playback,
  ) : _durationMicroseconds = duration.inMicroseconds;

  final _MotionAnimationGroup _group;
  List<VoidCallback> _listeners = const <VoidCallback>[];
  List<AnimationStatusListener> _statusListeners = const <AnimationStatusListener>[];
  int _durationMicroseconds;
  Curve _curve;
  MotionPlayback _playback;
  double _rawValue = 0;
  double _startValue = 0;
  int? _startTimeMicroseconds;
  AnimationStatus _status = AnimationStatus.dismissed;
  bool _running = false;
  bool _disposed = false;

  Duration get duration => Duration(microseconds: _durationMicroseconds);
  set duration(Duration value) {
    if (_durationMicroseconds == value.inMicroseconds) {
      return;
    }
    _durationMicroseconds = value.inMicroseconds;
    _restartClockAtCurrentValue();
  }

  Curve get curve => _curve;
  set curve(Curve value) {
    if (_curve == value) {
      return;
    }
    _curve = value;
    _notifyListeners();
  }

  MotionPlayback get playback => _playback;
  set playback(MotionPlayback value) {
    if (_playback == value) {
      return;
    }
    _playback = value;
    _restartClockAtCurrentValue();
  }

  @override
  double get value => _curve.transform(_rawValue);

  @override
  AnimationStatus get status => _status;

  @override
  void addListener(VoidCallback listener) {
    assert(!_disposed, 'Cannot add a listener to a disposed Motion animation.');
    _listeners = List<VoidCallback>.of(_listeners)..add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    final index = _listeners.indexOf(listener);
    if (index == -1) {
      return;
    }
    _listeners = List<VoidCallback>.of(_listeners)..removeAt(index);
  }

  @override
  void addStatusListener(AnimationStatusListener listener) {
    assert(!_disposed, 'Cannot add a listener to a disposed Motion animation.');
    _statusListeners = List<AnimationStatusListener>.of(_statusListeners)..add(listener);
  }

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    final index = _statusListeners.indexOf(listener);
    if (index == -1) {
      return;
    }
    _statusListeners = List<AnimationStatusListener>.of(_statusListeners)..removeAt(index);
  }

  void start() {
    _running = true;
    _startValue = 0;
    _startTimeMicroseconds = _currentFrameTimeMicroseconds();
    _setRawValue(0);
    _setStatus(AnimationStatus.forward);
    _group.updateScheduling();
  }

  void stopAt(double value) {
    _running = false;
    _group.updateScheduling();
    _startTimeMicroseconds = null;
    _startValue = value;
    _setRawValue(value);
    _setStatus(
      switch (value) {
        0 => AnimationStatus.dismissed,
        1 => AnimationStatus.completed,
        _ => AnimationStatus.forward,
      },
    );
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _running = false;
    _group.updateScheduling();
    _listeners = const <VoidCallback>[];
    _statusListeners = const <AnimationStatusListener>[];
  }

  void _tick(Duration timeStamp) {
    if (!_running || _disposed) {
      return;
    }
    final frameMicroseconds = timeStamp.inMicroseconds;
    _startTimeMicroseconds ??= frameMicroseconds;
    final elapsedMicroseconds = frameMicroseconds - _startTimeMicroseconds!;

    switch (_playback) {
      case MotionPlayback.once:
        final progress = _startValue + (elapsedMicroseconds / _durationMicroseconds) * (1 - _startValue);
        if (progress >= 1) {
          _running = false;
          _startTimeMicroseconds = null;
          _startValue = 1;
          _setRawValue(1);
          if (!_disposed) {
            _setStatus(AnimationStatus.completed);
          }
          return;
        }
        _setRawValue(progress);
        return;
      case MotionPlayback.loop:
        final elapsedCycles = elapsedMicroseconds / _durationMicroseconds;
        _setRawValue((_startValue + elapsedCycles) % 1);
        return;
    }
  }

  bool get _isRunning => _running && !_disposed;

  void _restartClockAtCurrentValue() {
    _startValue = _rawValue;
    if (_running) {
      _startTimeMicroseconds = _currentFrameTimeMicroseconds();
    }
  }

  int? _currentFrameTimeMicroseconds() {
    final binding = SchedulerBinding.instance;
    final phase = binding.schedulerPhase;
    if (phase.index <= SchedulerPhase.idle.index || phase.index >= SchedulerPhase.postFrameCallbacks.index) {
      return null;
    }
    return binding.currentFrameTimeStamp.inMicroseconds;
  }

  void _setRawValue(double value) {
    if (_rawValue == value) {
      return;
    }
    _rawValue = value;
    _notifyListeners();
  }

  void _setStatus(AnimationStatus value) {
    if (_status == value) {
      return;
    }
    _status = value;
    final listeners = _statusListeners;
    for (var index = 0; index < listeners.length; index += 1) {
      try {
        listeners[index](value);
      } catch (exception, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'oh_my_flutter motion animation',
            context: ErrorDescription('while notifying an animation status listener'),
          ),
        );
      }
    }
  }

  void _notifyListeners() {
    final listeners = _listeners;
    for (var index = 0; index < listeners.length; index += 1) {
      try {
        listeners[index]();
      } catch (exception, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'oh_my_flutter motion animation',
            context: ErrorDescription('while notifying an animation listener'),
          ),
        );
      }
    }
  }
}
