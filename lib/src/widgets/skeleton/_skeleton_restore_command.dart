part of 'skeleton.dart';

class _SkeletonRestoreCommand implements _SkeletonBoneCommand {
  const _SkeletonRestoreCommand();

  @override
  void replay(Canvas canvas, Paint paint) => canvas.restore();
}
