part of 'skeleton.dart';

class _SkeletonSaveCommand implements _SkeletonBoneCommand {
  const _SkeletonSaveCommand();

  @override
  void replay(Canvas canvas, Paint paint) => canvas.save();
}
