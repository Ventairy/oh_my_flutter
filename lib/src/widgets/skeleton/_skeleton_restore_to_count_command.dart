part of 'skeleton.dart';

class _SkeletonRestoreToCountCommand implements _SkeletonBoneCommand {
  const _SkeletonRestoreToCountCommand(this.count);

  final int count;

  @override
  void replay(Canvas canvas, Paint paint) => canvas.restoreToCount(count);
}
