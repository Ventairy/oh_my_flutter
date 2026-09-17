part of 'snap_list.dart';

class _SnapListTransitions {
  final Map<int, Set<VoidCallback>> _listeners = {};
  int? _from;
  int? _to;
  double _position = 0;
  double _progress = 0;
  AnimationStatus status = AnimationStatus.forward;

  (double, double, bool) values(int index) => (
    index == _to ? _progress : 1,
    index == _from ? _progress : 0,
    (index == _from || index == _to) && _to! < _from!,
  );

  void addListener(int index, VoidCallback listener) => (_listeners[index] ??= {}).add(listener);

  void removeListener(int index, VoidCallback listener) {
    final listeners = _listeners[index];
    listeners?.remove(listener);
    if (listeners?.isEmpty ?? false) _listeners.remove(index);
  }

  void update(double position, int count, {required bool reducedMotion}) {
    final oldFrom = _from;
    final oldTo = _to;
    final oldProgress = _progress;
    final lower = position.floor();
    final upper = position.ceil();
    if (reducedMotion || lower == upper || lower < 0 || upper >= count) {
      _from = null;
      _to = null;
      _progress = 0;
    } else {
      // Retain roles while reversing or interrupting within the same interval.
      if (!((_from == lower && _to == upper) || (_from == upper && _to == lower))) {
        _from = position >= _position ? lower : upper;
        _to = _from == lower ? upper : lower;
      }
      _progress = (position - _from!).abs().clamp(0.0, 1.0);
      if (_from != oldFrom || _to != oldTo || _progress > oldProgress) {
        status = AnimationStatus.forward;
      } else if (_progress < oldProgress) {
        status = AnimationStatus.reverse;
      }
    }
    _position = position;
    if (oldFrom == _from && oldTo == _to && oldProgress == _progress) return;
    _notify(oldFrom);
    if (oldTo != oldFrom) _notify(oldTo);
    if (_from != oldFrom && _from != oldTo) _notify(_from);
    if (_to != oldFrom && _to != oldTo && _to != _from) _notify(_to);
  }

  void _notify(int? index) {
    final listeners = _listeners[index];
    if (listeners == null) return;
    for (final listener in listeners) {
      listener();
    }
  }
}
