part of 'skeleton.dart';

class _SkeletonClipRectCommand implements _SkeletonBoneCommand {
  const _SkeletonClipRectCommand({
    required this.rect,
    required this.clipOp,
    required this.doAntiAlias,
  });

  final Rect rect;
  final ClipOp clipOp;
  final bool doAntiAlias;

  @override
  void replay(Canvas canvas, Paint paint) {
    canvas.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  }
}
