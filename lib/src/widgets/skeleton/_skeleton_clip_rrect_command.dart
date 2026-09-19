part of 'skeleton.dart';

class _SkeletonClipRRectCommand implements _SkeletonBoneCommand {
  const new({
    required this.rrect,
    required this.doAntiAlias,
  });

  final RRect rrect;
  final bool doAntiAlias;

  @override
  void replay(Canvas canvas, Paint paint) {
    canvas.clipRRect(rrect, doAntiAlias: doAntiAlias);
  }
}
