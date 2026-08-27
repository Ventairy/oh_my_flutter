part of 'skeleton.dart';

class _SkeletonClipPathCommand implements _SkeletonBoneCommand {
  _SkeletonClipPathCommand({required Path path, required this.doAntiAlias}) : path = Path.from(path);

  final Path path;
  final bool doAntiAlias;

  @override
  void replay(Canvas canvas, Paint paint) {
    canvas.clipPath(path, doAntiAlias: doAntiAlias);
  }
}
