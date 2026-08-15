part of 'motion.dart';

/// Provides imperative control over attached motion widgets.
///
/// A controller can be shared by multiple [Motion] and [TextMotion] widgets.
/// Commands apply to every attached motion widget, and calling a command while
/// none are attached does nothing.
class MotionController {
  /// Creates a motion controller.
  MotionController();

  final Set<VoidCallback> _playbacks = <VoidCallback>{};

  /// Restarts every attached motion from its initial visual state.
  ///
  /// Each effect waits for its configured delay before playing. Calling this
  /// during playback interrupts the current run. One-shot effects can be
  /// played again after they finish, and looping effects restart their cycle.
  void play() {
    final playbacks = List<VoidCallback>.of(_playbacks);
    for (final playback in playbacks) {
      playback();
    }
  }

  void _attach(VoidCallback playback) {
    _playbacks.add(playback);
  }

  void _detach(VoidCallback playback) {
    _playbacks.remove(playback);
  }
}
