part of 'skeleton.dart';

class _SkeletonRenderObjectWidget extends SingleChildRenderObjectWidget {
  const _SkeletonRenderObjectWidget({
    required this.enabled,
    required this.animate,
    required this.forceFrames,
    required this.style,
    required super.child,
  });

  final bool enabled;
  final bool animate;
  final bool forceFrames;
  final SkeletonStyle style;

  @override
  _RenderSkeleton createRenderObject(BuildContext context) {
    return _RenderSkeleton(
      enabled: enabled,
      animate: animate,
      forceFrames: forceFrames,
      style: style,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    if (renderObject is _RenderSkeleton) {
      renderObject
        ..enabled = enabled
        ..animate = animate
        ..forceFrames = forceFrames
        ..style = style;
    }
  }
}
