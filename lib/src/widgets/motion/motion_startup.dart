part of 'motion.dart';

/// Behavior applied when a [Motion] or [TextMotion] first mounts.
enum MotionStartup {
  /// Plays the configured effects automatically.
  play,

  /// Shows the effects at progress `0` without playing them.
  ///
  /// A later [MotionController.play] call starts normal playback.
  hold,

  /// Shows the effects at progress `1` without playing them.
  ///
  /// Skipping does not call effect lifecycle callbacks. A later
  /// [MotionController.play] call starts normal playback.
  skip,
}
