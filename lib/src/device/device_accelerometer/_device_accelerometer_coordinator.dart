part of 'pigeon_device_accelerometer.dart';

final class _DeviceAccelerometerCoordinator with WidgetsBindingObserver {
  new({required this._api, required this._samples});

  final DeviceAccelerometerHostApi _api;
  final Stream<DeviceAccelerometerPlatformSample> Function() _samples;
  final List<_DeviceAccelerometerListener> _listeners = [];
  Future<void> _pending = Future<void>.value();
  StreamSubscription<DeviceAccelerometerPlatformSample>? _source;
  WidgetsBinding? _binding;
  int? _interval;
  int? _lastTimestamp;
  int _generation = 0;
  bool _foreground = true;
  (Object, StackTrace)? _failure;

  Stream<DeviceAccelerometerSample> watch(Duration interval) => Stream<DeviceAccelerometerSample>.multi((controller) {
    final listener = _DeviceAccelerometerListener(
      controller: controller,
      intervalMicroseconds: interval.inMicroseconds,
    );
    if (_listeners.isEmpty) {
      final binding = _binding = WidgetsBinding.instance;
      _foreground = binding.lifecycleState == null || binding.lifecycleState == AppLifecycleState.resumed;
      binding.addObserver(this);
    }
    _listeners.add(listener);
    controller.onCancel = () {
      _listeners.remove(listener);
      if (_listeners.isEmpty) _removeObserver();
      return _update();
    };
    unawaited(_update());
  }, isBroadcast: true);

  void _removeObserver() {
    _binding?.removeObserver(this);
    _binding = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    for (final listener in _listeners) {
      listener.nextTimestamp = null;
    }
    unawaited(_update());
  }

  Future<void> _update() {
    final operation = _pending.then((_) => _reconcile());
    // Retain a successful queue tail so failures cannot block later attempts.
    _pending = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  int? get _desiredInterval {
    if (!_foreground || _listeners.isEmpty) return null;
    var result = _listeners.first.intervalMicroseconds;
    for (var index = 1; index < _listeners.length; index += 1) {
      final interval = _listeners[index].intervalMicroseconds;
      if (interval < result) result = interval;
    }
    return result;
  }

  Future<void> _reconcile() async {
    try {
      final failure = _failure;
      if (failure != null) {
        _failure = null;
        Error.throwWithStackTrace(failure.$1, failure.$2);
      }
      final desired = _desiredInterval;
      if (desired == _interval) return;
      if (desired == null) {
        await _stop();
        return;
      }
      await _api.configure(desired);
      _interval = desired;
      // All listeners may have canceled while configuration was pending.
      if (_desiredInterval == null) {
        await _stop();
        return;
      }
      if (_source != null) return;
      final generation = ++_generation;
      _lastTimestamp = null;
      _source = _samples().listen(
        (sample) {
          if (generation == _generation) _add(sample);
        },
        onError: (Object error, StackTrace stack) => _recordFailure(generation, error, stack),
        onDone: () =>
            _recordFailure(generation, StateError('Accelerometer updates ended unexpectedly'), StackTrace.current),
      );
    } on Object catch (error, stack) {
      final exception = PigeonDeviceAccelerometerPlatform._exception(error);
      final listeners = List<_DeviceAccelerometerListener>.of(_listeners);
      _listeners.clear();
      _removeObserver();
      try {
        await _stop();
      } on Object {
        // Preserve the original failure while attempting every cleanup step.
      }
      for (final listener in listeners) {
        listener.controller.addError(exception, stack);
        unawaited(listener.controller.close());
      }
      Error.throwWithStackTrace(exception, stack);
    }
  }

  Future<void> _stop() async {
    final hadSource = _source != null;
    final wasConfigured = _interval != null;
    _interval = null;
    _lastTimestamp = null;
    _generation += 1;
    try {
      if (wasConfigured || hadSource) await _api.configure(null);
    } finally {
      await _source?.cancel();
      _source = null;
    }
  }

  void _recordFailure(int generation, Object error, StackTrace stack) {
    if (generation != _generation || _failure != null) return;
    _failure = (error, stack);
    unawaited(_update());
  }

  void _add(DeviceAccelerometerPlatformSample native) {
    if (!_foreground || _listeners.isEmpty || _failure != null) return;
    final timestamp = native.timestampMicroseconds;
    if (!native.x.isFinite || !native.y.isFinite || !native.z.isFinite || timestamp < 0) {
      _recordFailure(_generation, StateError('Invalid accelerometer sample'), StackTrace.current);
      return;
    }
    if (_lastTimestamp != null && timestamp <= _lastTimestamp!) return;
    _lastTimestamp = timestamp;
    final sample = DeviceAccelerometerSample(
      x: native.x,
      y: native.y,
      z: native.z,
      timestamp: Duration(microseconds: timestamp),
    );
    for (final listener in _listeners) {
      listener.add(sample);
    }
  }
}
