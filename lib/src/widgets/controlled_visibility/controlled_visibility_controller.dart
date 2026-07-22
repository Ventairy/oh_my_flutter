part of 'controlled_visibility.dart';

/// Controls whether a [ControlledVisibility] widget is shown or hidden.
///
/// Call [show] or [hide] from parent code. A command issued before the
/// controller is attached is retained and applied when the widget mounts.
///
/// ```dart
/// final controller = ControlledVisibilityController();
///
/// controller.show();
/// controller.hide();
/// ```
class ControlledVisibilityController {
  /// Creates a controller for one [ControlledVisibility] widget.
  ControlledVisibilityController();

  void Function({required bool visible})? _onChanged;
  bool? _pendingVisibility;

  /// Shows the associated [ControlledVisibility] child.
  void show() => _setVisibility(visible: true);

  /// Hides the associated [ControlledVisibility] child.
  void hide() => _setVisibility(visible: false);

  void _setVisibility({required bool visible}) {
    final onChanged = _onChanged;
    if (onChanged != null) {
      onChanged(visible: visible);
      return;
    }

    _pendingVisibility = visible;
  }

  void _register(void Function({required bool visible}) onChanged) {
    _onChanged = onChanged;
    final pendingVisibility = _pendingVisibility;
    if (pendingVisibility == null) return;

    _pendingVisibility = null;
    onChanged(visible: pendingVisibility);
  }

  void _unregister() {
    _onChanged = null;
  }
}
