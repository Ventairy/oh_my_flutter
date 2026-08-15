part of 'morph.dart';

class _MorphVisibilityHandle extends ChangeNotifier {
  final ValueNotifier<bool> _tickersEnabled = ValueNotifier<bool>(true);
  bool _hidden = false;
  bool _disposed = false;

  bool get hidden => _hidden;

  ValueListenable<bool> get tickersEnabled => _tickersEnabled;

  set hidden(bool value) {
    if (_disposed || _hidden == value) return;
    _hidden = value;
    notifyListeners();
    scheduleMicrotask(() {
      if (!_disposed) _tickersEnabled.value = !_hidden;
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _tickersEnabled.dispose();
    super.dispose();
  }
}
