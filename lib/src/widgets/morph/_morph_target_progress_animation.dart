part of 'morph.dart';

final class _MorphTargetProgressAnimation extends Animation<double> with AnimationWithParentMixin<double> {
  _MorphTargetProgressAnimation({
    required this.parent,
    required this.begin,
    required this.end,
    required this.destinationProgress,
  }) : initialProgress = parent.value;

  @override
  final Animation<double> parent;
  final double begin;
  final double end;
  final double initialProgress;
  final double destinationProgress;

  @override
  double get value {
    final distance = destinationProgress - initialProgress;
    if (distance == 0) return end;
    final progress = ((parent.value - initialProgress) / distance).clamp(0.0, 1.0);
    return (begin + (end - begin) * progress).clamp(0.0, 1.0);
  }
}
