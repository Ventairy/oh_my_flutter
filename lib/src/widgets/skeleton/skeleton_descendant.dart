part of 'skeleton.dart';

/// Customizes how one subtree is represented inside an enabled [Skeleton].
///
/// The annotation has no visible effect outside an enabled ancestor [Skeleton],
/// so [child] renders normally in regular content. Annotations can be nested:
/// [SkeletonDescendantBehavior.deferToChildren] allows deeper annotations to
/// apply, while [SkeletonDescendantBehavior.paintAsBone] and
/// [SkeletonDescendantBehavior.hide] finish the annotated branch.
///
/// See the [Skeleton guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/skeleton.md)
/// for behavior examples and nesting guidance.
class SkeletonDescendant extends SingleChildRenderObjectWidget {
  /// Creates a skeleton annotation around [child].
  const SkeletonDescendant({
    required this.behavior,
    required super.child,
    super.key,
  });

  /// How the annotated subtree appears inside an enabled [Skeleton].
  final SkeletonDescendantBehavior behavior;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSkeletonDescendant(behavior);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderObject renderObject,
  ) {
    (renderObject as _RenderSkeletonDescendant).behavior = behavior;
  }
}
