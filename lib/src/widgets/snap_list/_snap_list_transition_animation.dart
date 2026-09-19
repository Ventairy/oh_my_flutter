part of 'snap_list.dart';

class _SnapListTransitionAnimation extends Animation<double> with ChangeNotifier, AnimationLocalStatusListenersMixin {
  new(this._value) : _status = _value == 1 ? AnimationStatus.completed : AnimationStatus.dismissed;

  double _value;
  AnimationStatus _status;

  @override
  double get value => _value;

  @override
  AnimationStatus get status => _status;

  void update(double value, {required AnimationStatus status}) {
    final nextStatus = switch (value) {
      0 => AnimationStatus.dismissed,
      1 => AnimationStatus.completed,
      _ => status,
    };
    final valueChanged = value != _value;
    final statusChanged = nextStatus != _status;
    _value = value;
    _status = nextStatus;
    if (valueChanged) notifyListeners();
    if (statusChanged) notifyStatusListeners(nextStatus);
  }

  @override
  void didRegisterListener() {}

  @override
  void didUnregisterListener() {}

  @override
  void dispose() {
    clearStatusListeners();
    super.dispose();
  }
}
