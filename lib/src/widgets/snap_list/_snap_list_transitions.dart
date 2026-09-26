part of 'snap_list.dart';

class _SnapListTransitions {
  final Map<int, Set<VoidCallback>> _listeners = {};
  int? _from;
  int? _to;
  int? _pendingIncoming;
  int? _trailingIndex;
  double _pixels = 0;
  double _progress = 0;
  ({int index, double anchor, double extent})? _trailingDeparture;
  AnimationStatus status = AnimationStatus.forward;

  ({double incoming, double outgoing, bool isReverse, bool involvesTrailing}) values(int index) => (
    incoming: index == _to ? _progress : (index == _pendingIncoming ? 0 : 1),
    outgoing: _outgoingValue(index),
    isReverse: (index == _from || index == _to) && _to! < _from!,
    involvesTrailing:
        index == _trailingDeparture?.index ||
        ((index == _from || index == _to) && (_from == _trailingIndex || _to == _trailingIndex)),
  );

  void addListener(int index, VoidCallback listener) => (_listeners[index] ??= {}).add(listener);

  void removeListener(int index, VoidCallback listener) {
    final listeners = _listeners[index];
    listeners?.remove(listener);
    if (listeners?.isEmpty ?? false) _listeners.remove(index);
  }

  double _outgoingValue(int index) {
    final departure = _trailingDeparture;
    if (departure != null && index == departure.index) {
      return ((_pixels - departure.anchor) / departure.extent).clamp(0.0, 1.0);
    }
    return index == _from ? _progress : 0;
  }

  void update(
    double position,
    int count, {
    required double pixels,
    required bool reducedMotion,
    ({int index, double anchor, double extent})? trailing,
  }) {
    final oldFrom = _from;
    final oldTo = _to;
    final oldProgress = _progress;
    final oldPendingIncoming = _pendingIncoming;
    final oldTrailingDeparture = _trailingDeparture;
    final oldTrailingIndex = _trailingIndex;
    _trailingIndex = trailing?.index;
    final lower = position.floor();
    final upper = position.ceil();
    if (reducedMotion || lower == upper || lower < 0 || upper >= count) {
      _from = null;
      _to = null;
      _progress = 0;
    } else {
      // Retain roles while reversing or interrupting within the same interval.
      if (!((_from == lower && _to == upper) || (_from == upper && _to == lower))) {
        _from = pixels >= _pixels ? lower : upper;
        _to = _from == lower ? upper : lower;
      }
      _progress = (position - _from!).abs().clamp(0.0, 1.0);
      if (_from != oldFrom || _to != oldTo || _progress > oldProgress) {
        status = AnimationStatus.forward;
      } else if (_progress < oldProgress) {
        status = AnimationStatus.reverse;
      }
    }
    // The prepared trailer can paint outside an unclipped viewport. Keep its
    // user-supplied arrival effect at the start until the reveal begins.
    _pendingIncoming = !reducedMotion && trailing != null && position <= trailing.index - 1 ? trailing.index : null;
    // Preserve the last card's departure distance when items append during a
    // reveal, so its effect does not jump back to the longer item stride.
    if (reducedMotion) {
      _trailingDeparture = null;
    } else if (trailing != null &&
        trailing.extent > 0 &&
        ((_from == trailing.index - 1 && _to == trailing.index) || position == trailing.index)) {
      _trailingDeparture = (index: trailing.index - 1, anchor: trailing.anchor, extent: trailing.extent);
    } else if (oldTrailingDeparture != null &&
        (_from != oldTrailingDeparture.index || _to != oldTrailingDeparture.index + 1)) {
      _trailingDeparture = null;
    }
    _pixels = pixels;
    if (oldFrom == _from &&
        oldTo == _to &&
        oldProgress == _progress &&
        oldPendingIncoming == _pendingIncoming &&
        oldTrailingDeparture == _trailingDeparture &&
        oldTrailingIndex == _trailingIndex) {
      return;
    }
    _notify(oldFrom);
    if (oldTo != oldFrom) _notify(oldTo);
    if (_from != oldFrom && _from != oldTo) _notify(_from);
    if (_to != oldFrom && _to != oldTo && _to != _from) _notify(_to);
    if (oldPendingIncoming != _pendingIncoming) {
      _notify(oldPendingIncoming);
      _notify(_pendingIncoming);
    }
    if (oldTrailingDeparture != _trailingDeparture) {
      _notify(oldTrailingDeparture?.index);
      if (oldTrailingDeparture?.index != _trailingDeparture?.index) _notify(_trailingDeparture?.index);
    }
  }

  void _notify(int? index) {
    final listeners = _listeners[index];
    if (listeners == null) return;
    for (final listener in listeners) {
      listener();
    }
  }
}
