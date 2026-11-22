import 'package:flutter/widgets.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class TwoBlurredBreakupsEffect extends MotionEffect {
  const new();

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..blur(3)
      ..disintegrate(progress: progress, direction: const Offset(1, 0), particleSize: 12)
      ..blur(4)
      ..disintegrate(progress: progress, direction: const Offset(0, 1));
  }
}
