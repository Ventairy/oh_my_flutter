import 'dart:ui';

/// Tracks lifecycle and focus changes during one swipe timing window.
final class InteractiveSwipeDismissBenchmarkInterruptionTracker {
  /// Creates a tracker with the binding's currently known lifecycle state.
  InteractiveSwipeDismissBenchmarkInterruptionTracker(this._lifecycleState);

  AppLifecycleState? _lifecycleState;
  ViewFocusState? _viewFocusState;
  int? _viewId;
  bool _windowIsActive = false;
  bool _windowCollectsFrames = false;
  final List<String> _invalidReasons = <String>[];

  /// Whether the application and benchmark view are currently interactive.
  bool get isInteractive {
    final lifecycleIsInteractive = switch (_lifecycleState) {
      null || AppLifecycleState.resumed => true,
      _ => false,
    };
    final viewIsInteractive = switch (_viewFocusState) {
      null || ViewFocusState.focused => true,
      _ => false,
    };
    return lifecycleIsInteractive && viewIsInteractive;
  }

  /// Reasons the current measured window is invalid.
  List<String> get invalidReasons => List<String>.unmodifiable(_invalidReasons);

  /// Associates focus events with the benchmark's Flutter view.
  set viewId(int value) => _viewId = value;

  /// Flutter view whose focus events belong to the benchmark.
  int? get viewId => _viewId;

  /// Starts tracking one frame window.
  void startWindow({required bool collectFrames}) {
    _windowIsActive = true;
    _windowCollectsFrames = collectFrames;
    _invalidReasons.clear();
    if (collectFrames && !isInteractive) {
      _invalidReasons.add('window_started_noninteractive');
    }
  }

  /// Stops tracking the current frame window.
  void endWindow() {
    _windowIsActive = false;
    _windowCollectsFrames = false;
  }

  /// Records a binding lifecycle notification.
  bool updateLifecycle(AppLifecycleState state) {
    final previous = _lifecycleState;
    if (previous == state) return false;
    _lifecycleState = state;
    _invalidate(
      'app_lifecycle:${previous?.name ?? 'unknown'}->${state.name}',
    );
    return true;
  }

  /// Records a Flutter view-focus notification.
  bool updateViewFocus(ViewFocusEvent event) {
    if (event.viewId != _viewId) return false;
    final previous = _viewFocusState;
    if (previous == event.state) return false;
    _viewFocusState = event.state;
    _invalidate(
      'view_focus:${previous?.name ?? 'unknown'}->${event.state.name}',
    );
    return true;
  }

  void _invalidate(String reason) {
    if (!_windowIsActive || !_windowCollectsFrames) return;
    _invalidReasons.add(reason);
  }
}
