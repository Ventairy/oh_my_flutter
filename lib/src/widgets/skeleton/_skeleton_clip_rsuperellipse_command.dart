part of 'skeleton.dart';

class _SkeletonClipRSuperellipseCommand implements _SkeletonBoneCommand {
  const _SkeletonClipRSuperellipseCommand({
    required this.rsuperellipse,
    required this.doAntiAlias,
  });

  final ui.RSuperellipse rsuperellipse;
  final bool doAntiAlias;

  @override
  void replay(Canvas canvas, Paint paint) {
    canvas.clipRSuperellipse(rsuperellipse, doAntiAlias: doAntiAlias);
  }
}
