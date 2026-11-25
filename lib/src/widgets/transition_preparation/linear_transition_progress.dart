import 'package:flutter/animation.dart';

/// Package-internal timeline with known linear, uninterrupted playback.
class LinearTransitionProgress extends Animation<double> with AnimationWithParentMixin<double> {
  /// Follows [parent] over the full [duration].
  new(this.parent, this.duration);

  @override
  final Animation<double> parent;

  /// Duration of the linear zero-to-one segment.
  final Duration duration;

  @override
  double get value => parent.value;
}
