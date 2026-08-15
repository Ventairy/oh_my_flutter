part of 'morph.dart';

class _MorphFlightPaintHandle extends ChangeNotifier {
  bool _visible = true;

  bool get visible => _visible;

  void hide() {
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }
}
