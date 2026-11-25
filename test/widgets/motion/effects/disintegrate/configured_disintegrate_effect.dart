import 'package:flutter/widgets.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class ConfiguredDisintegrateEffect extends MotionEffect {
  const new({
    this.progress,
    this.direction = Offset.zero,
    this.changeTopology = false,
    this.declaredBounds,
    super.playback,
    super.onStart,
    super.onEnd,
    super.delay,
    super.duration,
  });

  final double? progress;
  final Offset direction;
  final bool changeTopology;
  final MotionEffectBounds? declaredBounds;

  @override
  MotionEffectBounds? get bounds => declaredBounds;

  @override
  void apply(double value, MotionEffectTransform transform) {
    transform.disintegrate(
      progress: progress ?? value,
      direction: direction,
    );
    if (changeTopology && value > 0) transform.disintegrate(progress: value, direction: direction);
  }
}
