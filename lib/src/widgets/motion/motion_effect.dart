part of 'motion.dart';

/// Describes a visual motion treatment applied by [Motion].
///
/// Extend this class to create reusable effects without owning an animation
/// controller. [buildTransition] receives a read-only animation and the
/// existing child. Prefer render-object-backed Flutter transitions, such as
/// [FadeTransition], when one fits. Otherwise use an [AnimatedBuilder] with its
/// `child` parameter so animation frames rebuild only a shallow wrapper. Do
/// not create another controller or ticker inside an effect.
///
/// A one-shot effect receives progress from `0` to `1` and remains at `1`
/// after completion. A looping effect repeatedly receives `0` through `1`, so
/// its visual states at both endpoints should be equivalent.
///
/// ```dart
/// class RotateInMotionEffect extends MotionEffect {
///   const RotateInMotionEffect()
///       : super(duration: Duration(milliseconds: 240));
///
///   @override
///   Widget buildTransition(
///     BuildContext context,
///     Animation<double> animation,
///     Widget child,
///   ) {
///     return RotationTransition(turns: animation, child: child);
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
  /// and then this callback without scheduling animation frames.
  final VoidCallback? onEnd;

  /// Builds the visual transition around [child].
  ///
  /// This method is called when [Motion] builds, not on every animation frame.
  /// Use [animation] with an animated or transition widget and pass [child] to
  /// that widget without rebuilding it inside a per-frame callback.
  Widget buildTransition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  );
}
