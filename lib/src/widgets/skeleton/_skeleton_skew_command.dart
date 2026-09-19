part of 'skeleton.dart';

class _SkeletonSkewCommand implements _SkeletonBoneCommand {
  const new(this.sx, this.sy);

  final double sx;
  final double sy;

  @override
  void replay(Canvas canvas, Paint paint) => canvas.skew(sx, sy);
}
