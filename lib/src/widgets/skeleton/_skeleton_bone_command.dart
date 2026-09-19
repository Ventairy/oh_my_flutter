part of 'skeleton.dart';

// Commands intentionally use one polymorphic hot-path method so the captured
// canvas stream can be replayed without type switches or closures.
abstract interface class _SkeletonBoneCommand {
  void replay(Canvas canvas, Paint paint);
}
