part of 'motion.dart';

/// Chooses how captured motion is displayed alongside the live child.
enum MotionRenderPresentation {
  /// Shows the captured effect in place of the child during playback.
  replace,

  /// Shows the captured effect above the live child, which can change underneath.
  overlay,
}
