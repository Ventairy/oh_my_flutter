part of 'skeleton.dart';

class _SkeletonDrawPathCommand implements _SkeletonBoneCommand {
  new(Path path) : path = Path.from(path);

  final Path path;

  @override
  void replay(Canvas canvas, Paint paint) => canvas.drawPath(path, paint);
}
