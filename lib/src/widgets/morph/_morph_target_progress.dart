part of 'morph.dart';

final class _MorphTargetProgress {
  _MorphTargetProgress(double value) : curved = AlwaysStoppedAnimation(value), uncurved = AlwaysStoppedAnimation(value);

  Animation<double> curved;
  Animation<double> uncurved;
  bool participates = false;

  void freeze() {
    curved = AlwaysStoppedAnimation(curved.value.clamp(0.0, 1.0));
    uncurved = AlwaysStoppedAnimation(uncurved.value.clamp(0.0, 1.0));
  }

  void settle(double value) {
    curved = value == 1 ? kAlwaysCompleteAnimation : kAlwaysDismissedAnimation;
    uncurved = curved;
  }
}
