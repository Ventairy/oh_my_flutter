import 'package:flutter/widgets.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class ComposedDisintegrateEffect extends MotionEffect {
  const new({
    this.scaleFirst = false,
    this.secondStage = false,
    this.direction = const Offset(0, -1),
    super.onStart,
    super.onEnd,
  }) : super(duration: const Duration(seconds: 2));

  final bool scaleFirst;
  final bool secondStage;
  final Offset direction;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    if (scaleFirst) transform.scale(1 - 0.5 * progress);
    transform.disintegrate(progress: progress, direction: direction, particleSize: 4);
    if (secondStage) transform.disintegrate(progress: progress, direction: const Offset(1, 0), particleSize: 2.2);
    if (!scaleFirst) transform.scale(1 - 0.5 * progress);
  }
}
