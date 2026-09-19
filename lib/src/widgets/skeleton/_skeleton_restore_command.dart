part of 'skeleton.dart';

class _SkeletonRestoreCommand implements _SkeletonBoneCommand {
  const new();

  @override
  void replay(Canvas canvas, Paint paint) => canvas.restore();
}
