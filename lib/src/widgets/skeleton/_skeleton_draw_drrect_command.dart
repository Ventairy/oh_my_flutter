part of 'skeleton.dart';

class _SkeletonDrawDRRectCommand implements _SkeletonBoneCommand {
  const _SkeletonDrawDRRectCommand(this.outer, this.inner);

  final RRect outer;
  final RRect inner;

  @override
  void replay(Canvas canvas, Paint paint) {
    canvas.drawDRRect(outer, inner, paint);
  }
}
