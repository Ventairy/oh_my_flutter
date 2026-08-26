part of 'skeleton.dart';

class _SkeletonDrawOvalCommand implements _SkeletonBoneCommand {
  const _SkeletonDrawOvalCommand(this.rect);

  final Rect rect;

  @override
  void replay(Canvas canvas, Paint paint) => canvas.drawOval(rect, paint);
}
