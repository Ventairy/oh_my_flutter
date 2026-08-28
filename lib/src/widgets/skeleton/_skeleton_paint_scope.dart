part of 'skeleton.dart';

class _SkeletonPaintScope {
  _SkeletonPaintScope({
    required this.bounds,
    required this.deferredPaintLevels,
    required this.ignoreAnnotations,
  });

  final Rect bounds;
  final int deferredPaintLevels;
  final bool ignoreAnnotations;

  bool hasOwnVisiblePaint = false;
  bool capturesOwnPaint = false;
  bool hasDescendantBone = false;
  bool fallbackRecorded = false;

  int get childDeferredPaintLevels {
    if (!hasOwnVisiblePaint || capturesOwnPaint) return deferredPaintLevels;
    return deferredPaintLevels - 1;
  }
}
