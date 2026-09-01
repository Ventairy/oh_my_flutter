import 'dart:math' as math;
import 'dart:ui';

/// Produces one bounded, repeating free-drag path below dismissal distance.
final class InteractiveSwipeDismissBenchmarkMotion {
  /// Creates a deterministic drag path within [viewportSize].
  const InteractiveSwipeDismissBenchmarkMotion({
    required this.origin,
    required this.viewportSize,
  });

  /// Frames in one complete forward-and-reverse drag cycle.
  static const int framesPerCycle = 48;

  /// Starting global pointer coordinate.
  final Offset origin;

  /// Logical size used to keep the primary travel safely below threshold.
  final Size viewportSize;

  /// Greatest primary-axis travel produced by this path.
  double get maximumPrimaryTravel => math.min(120, viewportSize.height * 0.18);

  /// Returns the global pointer coordinate for zero-based [step].
  Offset positionForStep(int step) {
    assert(step >= 0, 'step must not be negative.');
    final phase = step % framesPerCycle;
    const halfCycle = framesPerCycle ~/ 2;
    final isForward = phase <= halfCycle;
    final double normalizedPrimary;
    if (isForward) {
      normalizedPrimary = phase / halfCycle;
    } else {
      normalizedPrimary = (framesPerCycle - phase) / halfCycle;
    }
    final primary = 24 + (maximumPrimaryTravel - 24) * normalizedPrimary;

    final double cross;
    if (isForward) {
      cross = -18 + (36 * phase / halfCycle);
    } else {
      cross = 18 - (36 * (phase - halfCycle) / halfCycle);
    }
    return origin + Offset(cross, primary);
  }
}
