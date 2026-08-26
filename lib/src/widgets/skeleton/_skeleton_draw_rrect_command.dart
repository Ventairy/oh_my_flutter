part of 'skeleton.dart';

class _SkeletonDrawRRectCommand implements _SkeletonBoneCommand {
  const _SkeletonDrawRRectCommand(this.rrect);

  final RRect rrect;

  @override
  void replay(Canvas canvas, Paint paint) => canvas.drawRRect(rrect, paint);
}
