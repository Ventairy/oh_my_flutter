part of '../motion.dart';

class _AnimatedMotionTranslation extends SingleChildRenderObjectWidget {
  const _AnimatedMotionTranslation.move({
    required this.animation,
    required this.begin,
    required this.end,
    required super.child,
  }) : floatingDistance = null;

  const _AnimatedMotionTranslation.floating({
    required this.animation,
    required double distance,
    required super.child,
  }) : begin = Offset.zero,
       end = Offset.zero,
       floatingDistance = distance;

  final Animation<double> animation;
  final Offset begin;
  final Offset end;
  final double? floatingDistance;

  @override
  _RenderAnimatedMotionTranslation createRenderObject(BuildContext context) {
    return _RenderAnimatedMotionTranslation(
      animation: animation,
      begin: begin,
      end: end,
      floatingDistance: floatingDistance,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAnimatedMotionTranslation renderObject,
  ) {
    renderObject
      ..animation = animation
      ..begin = begin
      ..end = end
      ..floatingDistance = floatingDistance;
  }
}
