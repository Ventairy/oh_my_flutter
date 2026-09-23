part of 'morph.dart';

class _MorphVisibilityHandle extends ChangeNotifier {
  final ValueNotifier<bool> _tickersEnabled = ValueNotifier<bool>(true);
  bool _hidden = false;
  int _hiddenPaintLeases = 0;
  bool _disposed = false;
  Set<GroupLink> _contentGroups = {};
  final Map<GroupLink, GroupPresentationLease> _groupPresentations = {};

  void setContentGroups(Iterable<GroupLink> groups) {
    _contentGroups = Set<GroupLink>.identity()..addAll(groups);
    _updateGroupPresentations();
  }

  void _updateGroupPresentations() {
    _groupPresentations.removeWhere((group, presentation) {
      if (_hidden && _contentGroups.contains(group)) return false;
      presentation.release();
      return true;
    });
    if (!_hidden) return;
    for (final group in _contentGroups) {
      _groupPresentations.putIfAbsent(group, () => GroupCaptureAccess.hide(group));
    }
  }

  bool get hidden => _hidden;

  bool get hasContentGroups => _contentGroups.isNotEmpty;

  bool get paintsWhileHidden => _hiddenPaintLeases > 0;

  ValueListenable<bool> get tickersEnabled => _tickersEnabled;

  T paintHiddenGroups<T>(T Function() paint) => GroupCaptureAccess.paintSuppressed(_contentGroups, paint);

  VoidCallback beginHiddenPaint() {
    assert(!_disposed, 'A disposed Morph endpoint cannot begin hidden painting.');
    _hiddenPaintLeases += 1;
    if (_hiddenPaintLeases == 1) {
      notifyListeners();
    }
    var released = false;
    return () {
      if (released) return;
      released = true;
      if (_disposed) return;
      assert(_hiddenPaintLeases > 0, 'A hidden paint lease must be acquired before it is released.');
      _hiddenPaintLeases -= 1;
      if (_hiddenPaintLeases == 0) {
        notifyListeners();
      }
    };
  }

  set hidden(bool value) {
    if (_disposed || _hidden == value) return;
    _hidden = value;
    _updateGroupPresentations();
    notifyListeners();
    scheduleMicrotask(() {
      if (!_disposed) _tickersEnabled.value = !_hidden;
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final presentation in _groupPresentations.values) {
      presentation.release();
    }
    _groupPresentations.clear();
    _contentGroups.clear();
    _hiddenPaintLeases = 0;
    _tickersEnabled.dispose();
    super.dispose();
  }
}
