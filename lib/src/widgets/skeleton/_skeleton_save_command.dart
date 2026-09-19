part of 'skeleton.dart';

class _SkeletonSaveCommand implements _SkeletonBoneCommand {
  const new();

  @override
  void replay(Canvas canvas, Paint paint) => canvas.save();
}
