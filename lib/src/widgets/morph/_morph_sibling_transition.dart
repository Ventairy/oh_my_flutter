part of 'morph.dart';

final class _MorphSiblingTransition {
  _MorphSiblingTransition({required this.group, required this.coordinator, required _MorphActiveFlight flight})
    : animation = flight.flightAnimation,
      curvedAnimation = CurvedAnimation(parent: flight.flightAnimation, curve: flight.curve),
      controllerLease = flight.controllerLease {
    controllerLease?.retain();
    final destinationProgress = flight.completesAtSource ? 0.0 : 1.0;
    for (final entry in group.progress.entries) {
      final progress = entry.value;
      final end = identical(entry.key, flight.destinationHandle.target) ? 1.0 : 0.0;
      progress.participates = progress.curved.value != 0 || progress.uncurved.value != 0 || end != 0;
      progress.curved = _MorphTargetProgressAnimation(
        parent: curvedAnimation,
        begin: progress.curved.value,
        end: end,
        destinationProgress: destinationProgress,
      );
      progress.uncurved = _MorphTargetProgressAnimation(
        parent: animation,
        begin: progress.uncurved.value,
        end: end,
        destinationProgress: destinationProgress,
      );
    }
    animation.addStatusListener(_statusChanged);
  }

  final _MorphTargetGroup group;
  final _MorphCoordinator coordinator;
  final Animation<double> animation;
  final CurvedAnimation curvedAnimation;
  final _MorphControllerLease? controllerLease;
  bool _disposed = false;

  void _statusChanged(AnimationStatus status) {
    if (!status.isCompleted && !status.isDismissed) return;
    // Wait until every listener has consumed the final animation value.
    scheduleMicrotask(dispose);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    animation.removeStatusListener(_statusChanged);
    if (identical(group.siblingTransition, this)) {
      for (final progress in group.progress.values) {
        progress.freeze();
      }
      group.siblingTransition = null;
      coordinator._updateSiblingProgress(group);
    }
    curvedAnimation.dispose();
    controllerLease?.release();
  }
}
