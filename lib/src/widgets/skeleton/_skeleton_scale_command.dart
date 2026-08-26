part of 'skeleton.dart';

class _SkeletonScaleCommand implements _SkeletonBoneCommand {
  const _SkeletonScaleCommand(this.sx, this.sy);

  final double sx;
  final double? sy;

  @override
  void replay(Canvas canvas, Paint paint) => canvas.scale(sx, sy);
}
