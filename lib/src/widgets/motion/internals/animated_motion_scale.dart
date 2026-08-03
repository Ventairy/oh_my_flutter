part of '../motion.dart';

class _AnimatedMotionScale extends SingleChildRenderObjectWidget {
  const _AnimatedMotionScale({
    required this.animation,
    required this.beginScale,
    required super.child,
  });

  final Animation<double> animation;
  final double beginScale;

  @override
  _RenderAnimatedMotionScale createRenderObject(BuildContext context) {
    return _RenderAnimatedMotionScale(
      animation: animation,
      beginScale: beginScale,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAnimatedMotionScale renderObject,
  ) {
    renderObject
      ..animation = animation
      ..beginScale = beginScale;
  }
}
