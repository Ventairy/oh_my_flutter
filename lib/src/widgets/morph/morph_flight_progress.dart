part of 'morph.dart';

/// Apply independent timing to custom flight content while retaining the
/// surface's animation progress.
@immutable
final class MorphFlightProgress {
  /// Creates the timing values used to interpolate a flight.
  const new({
    required this.curvedProgress,
    required this.uncurvedProgress,
    required this.flightKind,
    required this.animationStatus,
  });

  /// Progress after the flight's curve, which may overshoot the endpoint range.
  final double curvedProgress;

  /// Progress before Morph's curve is applied.
  ///
  /// A supplying route may already ease this value or control it through a
  /// gesture, so it does not necessarily represent linear elapsed time.
  final double uncurvedProgress;

  /// Why this flight started.
  ///
  /// An interrupted push retains its kind when playback reverses.
  final MorphFlightKind flightKind;

  /// The underlying flight animation's current playback status.
  ///
  /// This describes the flight, not its containing route's animation.
  final AnimationStatus animationStatus;

  @override
  bool operator ==(Object other) =>
      other is MorphFlightProgress &&
      curvedProgress == other.curvedProgress &&
      uncurvedProgress == other.uncurvedProgress &&
      flightKind == other.flightKind &&
      animationStatus == other.animationStatus;

  @override
  int get hashCode => Object.hash(curvedProgress, uncurvedProgress, flightKind, animationStatus);
}
