part of 'skeleton.dart';

class _SkeletonPaintState {
  _SkeletonPaintScope? activeScope;
  int boneCount = 0;

  bool beginVisiblePaint() {
    final scope = activeScope;
    if (scope == null || scope.hasDescendantBone) return false;
    if (!scope.hasOwnVisiblePaint) {
      scope
        ..hasOwnVisiblePaint = true
        ..capturesOwnPaint = scope.deferredPaintLevels == 0;
    }
    return scope.capturesOwnPaint;
  }
}
