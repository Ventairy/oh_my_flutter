part of 'motion.dart';

/// Describes a visual motion treatment shared by [Motion] and [TextMotion].
///
/// Extend this class by implementing [apply]. The same effect can drive the
/// complete child in [Motion] and every staggered grapheme in [TextMotion].
///
/// A one-shot effect receives progress from `0` to `1` and remains at `1`
/// after completion. A looping effect repeatedly receives `0` through `1`, so
/// its visual states at both endpoints should be equivalent.
///
/// ```dart
/// class SlideInMotionEffect extends MotionEffect {
///   const SlideInMotionEffect()
///       : super(duration: Duration(milliseconds: 240));
///
///   @override
///   void apply(double progress, MotionEffectTransform transform) {
///     transform.translate(x: 24 * (1 - progress), y: 0);
///   }
/// }
/// ```
@immutable
abstract class MotionEffect {
  /// Creates a motion effect with its playback configuration.
  const MotionEffect({
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.linear,
    this.playback = MotionPlayback.once,
    this.onStart,
    this.onEnd,
  });

  /// Time to wait before this effect starts.
  ///
  /// The delay defaults to zero and must not be negative. Waiting does not use
  /// an animation ticker. Effects in [Motion.list] may use different delays
  /// to overlap or stagger their playback.
  final Duration delay;

  /// Time taken to move from animation progress `0` to `1`.
  ///
  /// For [MotionPlayback.loop], this is the duration of one complete cycle.
  /// [Motion] rejects zero and negative durations when mounted.
  final Duration duration;

  /// Curve applied to the animation progress before the effect receives it.
  final Curve curve;

  /// Whether this effect runs once or loops while mounted.
  final MotionPlayback playback;

  /// Called when this effect begins playback after its [delay].
  ///
  /// The callback fires independently for every effect in [Motion.list]. It
  /// does not fire while playback is paused by [TickerMode]. A one-shot effect
  /// skipped by a reduced-motion preference fires this callback immediately
  /// before [onEnd]. Rebuilding does not replay an effect or this callback.
  final VoidCallback? onStart;

  /// Called when this effect completes one-shot playback.
  ///
  /// The callback fires independently for every effect in [Motion.list]. It
  /// is not called when playback is canceled by removal or disposal. Looping
  /// effects do not complete while mounted, so they do not call this callback.
  /// A one-shot effect skipped by a reduced-motion preference calls [onStart]
  /// and then this callback immediately.
  final VoidCallback? onEnd;

  /// Applies this effect at curved [progress].
  ///
  /// Implementations must be deterministic, side-effect free, synchronous,
  /// and must not retain [transform].
  void apply(double progress, MotionEffectTransform transform);
}
