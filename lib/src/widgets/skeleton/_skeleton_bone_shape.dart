part of 'skeleton.dart';

class _SkeletonBoneShape {
  const new(this.shape, this.textDirection);

  final ShapeBorder shape;
  final TextDirection textDirection;

  _SkeletonBoneCommand forRect(Rect rect) {
    if (shape case RoundedRectangleBorder(:final borderRadius)) {
      return _SkeletonDrawRRectCommand(borderRadius.resolve(textDirection).toRRect(rect));
    }
    return _SkeletonDrawPathCommand(shape.getOuterPath(rect, textDirection: textDirection));
  }

  _SkeletonBoneCommand forDoubleRect(RRect outer, RRect inner) {
    if (shape case RoundedRectangleBorder(:final borderRadius)) {
      final resolved = borderRadius.resolve(textDirection);
      return _SkeletonDrawDRRectCommand(resolved.toRRect(outer.outerRect), resolved.toRRect(inner.outerRect));
    }
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(shape.getOuterPath(outer.outerRect, textDirection: textDirection), Offset.zero)
      ..addPath(shape.getOuterPath(inner.outerRect, textDirection: textDirection), Offset.zero);
    return _SkeletonDrawPathCommand(path);
  }
}
