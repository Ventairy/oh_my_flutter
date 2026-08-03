part of 'motion.dart';

/// Playback behaviors supported by a [MotionEffect].
enum MotionPlayback {
  /// Runs from progress `0` to `1` once and holds the final value.
  once,

  /// Repeats progress from `0` to `1` while the motion remains active.
  ///
  /// Looping effects should render equivalent states at `0` and `1` so the
  /// cycle has no visible discontinuity.
  loop,
}
