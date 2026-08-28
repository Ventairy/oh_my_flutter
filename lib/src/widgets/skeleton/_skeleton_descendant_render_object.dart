part of 'skeleton.dart';

class _RenderSkeletonDescendant extends RenderProxyBox {
  _RenderSkeletonDescendant(this._behavior);

  SkeletonDescendantBehavior _behavior;

  SkeletonDescendantBehavior get behavior => _behavior;

  set behavior(SkeletonDescendantBehavior value) {
    if (value == _behavior) return;
    _behavior = value;
    _invalidateSkeletonAncestor();
    markNeedsPaint();
  }

  void _invalidateSkeletonAncestor() {
    var ancestor = parent;
    while (ancestor != null && ancestor is! _RenderSkeleton) {
      ancestor = ancestor.parent;
    }
    ancestor?.markNeedsPaint();
  }
}
