import 'package:flutter/widgets.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class HeldTransformDisintegrateEffect extends MotionEffect {
  const new();

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..scale(0.5)
      ..translate(x: 20, y: 0)
      ..disintegrate(progress: progress, direction: Offset.zero);
  }
}
