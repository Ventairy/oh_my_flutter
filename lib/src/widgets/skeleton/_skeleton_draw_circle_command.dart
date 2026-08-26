part of 'skeleton.dart';

class _SkeletonDrawCircleCommand implements _SkeletonBoneCommand {
  const _SkeletonDrawCircleCommand(this.center, this.radius);

  final Offset center;
  final double radius;

  @override
  void replay(Canvas canvas, Paint paint) {
    canvas.drawCircle(center, radius, paint);
  }
}
