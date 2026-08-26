part of 'skeleton.dart';

class _SkeletonRotateCommand implements _SkeletonBoneCommand {
  const _SkeletonRotateCommand(this.radians);

  final double radians;

  @override
  void replay(Canvas canvas, Paint paint) => canvas.rotate(radians);
}
