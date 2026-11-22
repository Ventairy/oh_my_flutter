part of '../motion.dart';

class _MotionParticleBlur extends SingleChildRenderObjectWidget {
  const new({required this.applications, required super.child, this.preview = false});

  final List<_MotionApplication> applications;
  final bool preview;

  @override
  _RenderMotionParticleBlur createRenderObject(BuildContext context) =>
      _RenderMotionParticleBlur(applications, preview: preview);

  @override
  void updateRenderObject(BuildContext context, _RenderMotionParticleBlur renderObject) {
    renderObject.applications = applications;
  }
}
