part of 'skeleton.dart';

class _SkeletonDrawPathCommand implements _SkeletonBoneCommand {
  _SkeletonDrawPathCommand(Path path) : path = Path.from(path);

  final Path path;

  @override
  void replay(Canvas canvas, Paint paint) => canvas.drawPath(path, paint);
}
