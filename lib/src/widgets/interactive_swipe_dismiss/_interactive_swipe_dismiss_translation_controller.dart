part of 'interactive_swipe_dismiss.dart';

final class _InteractiveSwipeDismissTranslationController {
  double get dx => _dx;
  double _dx = 0;

  double get dy => _dy;
  double _dy = 0;

  _RenderInteractiveSwipeDismissTranslation? _renderObject;

  void setTranslation(double dx, double dy) {
    if (_dx == dx && _dy == dy) return;
    _dx = dx;
    _dy = dy;
    _renderObject?.setTranslation(dx, dy);
  }

  void attach(_RenderInteractiveSwipeDismissTranslation renderObject) {
    assert(
      _renderObject == null || identical(_renderObject, renderObject),
      'An InteractiveSwipeDismiss translation controller can only drive one '
      'render object.',
    );
    _renderObject = renderObject;
    renderObject.setTranslation(_dx, _dy);
  }

  void detach(_RenderInteractiveSwipeDismissTranslation renderObject) {
    if (identical(_renderObject, renderObject)) _renderObject = null;
  }
}
