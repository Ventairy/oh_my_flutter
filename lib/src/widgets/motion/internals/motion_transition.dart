part of '../motion.dart';

/// Applies shared motion effects to one widget subtree.
class _MotionTransition extends SingleChildRenderObjectWidget {
  const _MotionTransition({
    required this.applications,
    required super.child,
  });

  final List<_MotionApplication> applications;

  @override
  _RenderMotionTransition createRenderObject(BuildContext context) {
    return _RenderMotionTransition(applications: applications);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMotionTransition renderObject,
  ) {
    renderObject.applications = applications;
  }
}
