part of '../motion.dart';

/// Moves a child between two logical-pixel offsets.
///
/// [begin] and [end] are paint offsets relative to the child's layout
/// position. Movement does not affect surrounding layout, and hit testing
/// follows the translated child.
class MoveMotionEffect extends MotionEffect {
  /// Creates an effect that moves from [begin] to [end].
  const MoveMotionEffect({
    required this.begin,
    required this.end,
    super.delay = Duration.zero,
    super.duration = const Duration(milliseconds: 300),
    super.curve = Curves.linear,
    super.playback = MotionPlayback.once,
    super.onStart,
    super.onEnd,
  });

  /// Starting logical-pixel offset from the child's layout position.
  final Offset begin;

  /// Ending logical-pixel offset from the child's layout position.
  final Offset end;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.translate(
      x: begin.dx + (end.dx - begin.dx) * progress,
      y: begin.dy + (end.dy - begin.dy) * progress,
    );
  }
}
