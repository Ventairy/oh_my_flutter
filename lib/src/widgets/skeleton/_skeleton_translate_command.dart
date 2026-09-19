part of 'skeleton.dart';

class _SkeletonTranslateCommand implements _SkeletonBoneCommand {
  const new(this.dx, this.dy);

  final double dx;
  final double dy;

  @override
  void replay(Canvas canvas, Paint paint) => canvas.translate(dx, dy);
}
