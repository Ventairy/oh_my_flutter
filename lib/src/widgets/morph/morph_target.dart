part of 'morph.dart';

/// Connects appearances that can transition into each other.
///
/// Share the same instance through both appearances' [Morph.targets]. Keep it
/// stable across rebuilds, usually in the State that creates both appearances.
/// Separate instances never match, even when their [tag] values are equal.
/// A target needs no disposal.
///
/// See the [Morph guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph.md)
/// for setup and examples.
final class MorphTarget {
  /// Creates a shared transition contract between appearances.
  new({
    required this.tag,
    this.duration,
    this.reverseDuration,
    this.curve,
    this.reverseCurve,
    this.watchDestination = false,
    this.canMatch,
  }) : assert(_debugValidateDuration(duration), 'duration must not be negative.'),
       assert(
         _debugValidateDuration(reverseDuration),
         'reverseDuration must not be negative.',
       );

  /// Labels this connection in diagnostics.
  ///
  /// Matching and status use this target's identity, regardless of the tag.
  final Object tag;

  late final _status = _MorphTargetStatusListenable(this);

  /// Reads or watches the navigation result for this connection.
  ///
  /// Read `.value`, add a listener, or use a ValueListenableBuilder. Remove
  /// listeners when no longer needed; do not dispose the returned listenable.
  /// It starts at [MorphTagStatus.idle] before the target participates in
  /// navigation, then reports pending, unmatched, or the flight lifecycle.
  /// Terminal results remain until the next navigation. Local appearance
  /// changes do not update this status.
  ///
  /// Use [MorphTagStatus.unmatched] to select a fallback route transition.
  /// Completion and cancellation must not start another entrance or exit.
  /// Honor reduced motion separately.
  ValueListenable<MorphTagStatus> get status => _status;

  /// Sets the transition length when moving to a newer appearance.
  ///
  /// When omitted, the departing appearance inherits its nearest ancestor
  /// Morph's selected target duration. Without one, local transitions use
  /// 300 milliseconds and navigation follows the route animation.
  /// [reverseDuration] can give return flights a different length; when it is
  /// omitted, this duration applies in both directions.
  /// [Duration.zero] completes immediately. Must not be negative.
  /// Shorter transitions remain visually settled while simultaneous ones finish.
  final Duration? duration;

  /// Sets the transition length when returning to an earlier appearance.
  ///
  /// When omitted, [duration] applies in both directions. If both are omitted,
  /// the departing appearance inherits its nearest ancestor Morph's reverse
  /// timing. Without inherited timing, local returns use 300 milliseconds and
  /// route pops follow the route animation. [Duration.zero] completes
  /// immediately. Must not be negative.
  final Duration? reverseDuration;

  /// Sets the visual easing when moving to a newer appearance.
  ///
  /// When omitted, the departing appearance inherits its nearest ancestor
  /// Morph's effective curve, falling back to [Curves.linear]. Inherited timing
  /// can differ between directions when the appearances have different parents.
  /// [reverseCurve] can give return flights different easing; when it is
  /// omitted, this curve applies in both directions.
  /// Overshooting curves can produce progress outside the 0 to 1 interval.
  final Curve? curve;

  /// Sets the visual easing when returning to an earlier appearance.
  ///
  /// When omitted, [curve] applies in both directions. If both are omitted,
  /// the departing appearance inherits its nearest ancestor Morph's reverse
  /// curve, falling back to [Curves.linear]. When a flight changes direction,
  /// the new curve begins from the current visible state without a jump.
  final Curve? reverseCurve;

  /// Whether flights using this target follow changes to their destination.
  ///
  /// Enable this when either matching endpoint can move, resize, or change its
  /// captured visual while a flight travels toward it. Geometry, delegate
  /// properties, grouped content, and snapshotted descendants then refresh as
  /// one coherent endpoint revision. A custom delegate's
  /// [MorphFlightDelegate.properties] may run again when that revision changes;
  /// keep it synchronous and free of side effects.
  ///
  /// This applies in both directions because the target represents the shared
  /// connection. Leave it disabled for stationary destinations to avoid
  /// unnecessary observation and raster work.
  final bool watchDestination;

  /// Restricts which appearances may share a flight through this connection.
  ///
  /// Rejection tries the destination's next alternative target. Approval does
  /// not guarantee a flight: endpoints must be available and compatible.
  /// Keep this callback synchronous and side-effect-free. It runs once per
  /// proposed pair, including a new pop, but not on animation ticks or when
  /// cancelling an accepted gesture. Omit it to allow matching. Exceptions
  /// are reported through FlutterError and reject the candidate.
  final bool Function(MorphMatchContext match)? canMatch;

  static bool _debugValidateDuration(Duration? duration) {
    assert(duration == null || !duration.isNegative, 'duration must not be negative.');
    return true;
  }
}
