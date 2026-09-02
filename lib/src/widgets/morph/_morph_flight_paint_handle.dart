part of 'morph.dart';

class _MorphFlightPaintHandle extends ChangeNotifier {
  bool _visible = true;
  bool _handoffPrepared = false;

  bool get visible => _visible;
  bool get handoffPrepared => _handoffPrepared;

  void prepareHandoff() {
    if (_handoffPrepared) return;
    _handoffPrepared = true;
    notifyListeners();
  }

  void hideDuringPreparedPaint() {
    _visible = false;
  }

  void hide() {
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }
}
