part of 'skeleton.dart';

class _SkeletonRenderObjectWidget extends SingleChildRenderObjectWidget {
  const new({
    required this.enabled,
    required this.animate,
    required this.forceFrames,
    required this.style,
    required this.blend,
    required super.child,
  });

  final bool enabled;
  final bool animate;
  final bool forceFrames;
  final SkeletonStyle style;
  final Animation<double>? blend;

  @override
  _RenderSkeleton createRenderObject(BuildContext context) {
    return _RenderSkeleton(
      enabled: enabled,
      animate: animate,
      forceFrames: forceFrames,
      style: style,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      blend: blend,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    if (renderObject is _RenderSkeleton) {
      renderObject
        ..enabled = enabled
        ..animate = animate
        ..forceFrames = forceFrames
        ..style = style
        ..textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr
        ..blend = blend;
    }
  }
}
