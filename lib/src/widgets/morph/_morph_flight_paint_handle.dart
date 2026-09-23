part of 'morph.dart';

class _MorphFlightPaintHandle extends ChangeNotifier {
  new({required this.onRetiredPainted});

  final VoidCallback onRetiredPainted;
  bool _visible = true;
  bool _handoffPrepared = false;
  bool _retirementRequested = false;
  bool _retiredPaintReported = false;
  bool _retirementPaintRequestScheduled = false;

  bool get visible => _visible;
  bool get handoffPrepared => _handoffPrepared;
  bool get retirementRequested => _retirementRequested;

  void prepareHandoff() {
    if (_handoffPrepared) return;
    _handoffPrepared = true;
    notifyListeners();
  }

  void retireDuringPreparedPaint() {
    _visible = false;
    _retirementRequested = true;
    _retiredPaintReported = false;
    if (_retirementPaintRequestScheduled) return;
    _retirementPaintRequestScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _retirementPaintRequestScheduled = false;
      if (_retirementRequested && !_retiredPaintReported) {
        notifyListeners();
      }
    });
  }

  void reportRetiredPaint() {
    if (!_retirementRequested || _retiredPaintReported) return;
    _retiredPaintReported = true;
    onRetiredPainted();
  }

  void finishPreparedHandoff() {
    assert(
      !_visible && _handoffPrepared && _retiredPaintReported,
      'A prepared handoff must retire its painted layers before it finishes.',
    );
    _handoffPrepared = false;
    _retirementRequested = false;
  }

  void resumeAfterPreparedHandoff() {
    final paintChanged = !_visible || _handoffPrepared || _retirementRequested;
    _visible = true;
    _handoffPrepared = false;
    _retirementRequested = false;
    _retiredPaintReported = false;
    if (paintChanged) notifyListeners();
  }

  void hide() {
    if (!_visible && !_handoffPrepared && !_retirementRequested) return;
    _visible = false;
    _handoffPrepared = false;
    _retirementRequested = false;
    notifyListeners();
  }
}
