part of 'skeleton.dart';

class _SkeletonDescendantRenderObjectWidget extends SingleChildRenderObjectWidget {
  const new({
    required this.behavior,
    required super.child,
  });

  final SkeletonDescendantBehavior behavior;

  @override
  _RenderSkeletonDescendant createRenderObject(BuildContext context) => _RenderSkeletonDescendant(behavior);

  @override
  void updateRenderObject(BuildContext context, _RenderSkeletonDescendant renderObject) {
    renderObject.behavior = behavior;
  }
}
