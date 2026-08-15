part of 'morph.dart';

final class _MorphTransitionAnimation extends Animation<double> {
  _MorphTransitionAnimation(this._value) : _status = _statusForValue(_value);

  double _value;
  AnimationStatus _status;
  final List<VoidCallback> _listeners = <VoidCallback>[];
  final List<AnimationStatusListener> _statusListeners = <AnimationStatusListener>[];

  @override
  double get value => _value;

  @override
  AnimationStatus get status => _status;

  set value(double value) {
    if (_value == value) return;
    final previousValue = _value;
    _value = value;
    final nextStatus = switch (value) {
      <= 0 => AnimationStatus.dismissed,
      >= 1 => AnimationStatus.completed,
      _ when value < previousValue => AnimationStatus.reverse,
      _ => AnimationStatus.forward,
    };
    final statusChanged = _status != nextStatus;
    _status = nextStatus;
    _notifyValueListeners();
    if (statusChanged) _notifyStatusListeners();
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) {
    _statusListeners.add(listener);
  }

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    _statusListeners.remove(listener);
  }

  void dispose() {
    _listeners.clear();
    _statusListeners.clear();
  }

  void _notifyValueListeners() {
    if (_listeners.isEmpty) return;
    if (_listeners.length == 1) {
      _notifyValueListener(_listeners.first);
      return;
    }
    for (final listener in List<VoidCallback>.of(_listeners)) {
      if (_listeners.contains(listener)) {
        _notifyValueListener(listener);
      }
    }
  }

  void _notifyStatusListeners() {
    if (_statusListeners.isEmpty) return;
    if (_statusListeners.length == 1) {
      _notifyStatusListener(_statusListeners.first);
      return;
    }
    for (final listener in List<AnimationStatusListener>.of(
      _statusListeners,
    )) {
      if (_statusListeners.contains(listener)) {
        _notifyStatusListener(listener);
      }
    }
  }

  void _notifyValueListener(VoidCallback listener) {
    try {
      listener();
    } on Object catch (exception, stack) {
      _reportListenerError(
        exception,
        stack,
        'while notifying a Morph content transition listener',
      );
    }
  }

  void _notifyStatusListener(AnimationStatusListener listener) {
    try {
      listener(_status);
    } on Object catch (exception, stack) {
      _reportListenerError(
        exception,
        stack,
        'while notifying a Morph content transition status listener',
      );
    }
  }

  void _reportListenerError(
    Object exception,
    StackTrace stack,
    String context,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'oh_my_flutter Morph',
        context: ErrorDescription(context),
      ),
    );
  }

  static AnimationStatus _statusForValue(double value) => switch (value) {
    <= 0 => AnimationStatus.dismissed,
    >= 1 => AnimationStatus.completed,
    _ => AnimationStatus.forward,
  };
}
