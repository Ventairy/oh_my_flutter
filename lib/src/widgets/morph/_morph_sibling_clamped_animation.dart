part of 'morph.dart';

final class _MorphSiblingClampedAnimation extends Animation<double> with AnimationWithParentMixin<double> {
  const _MorphSiblingClampedAnimation(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value.clamp(0, 1);
}
