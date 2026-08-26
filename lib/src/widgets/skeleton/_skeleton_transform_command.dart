part of 'skeleton.dart';

class _SkeletonTransformCommand implements _SkeletonBoneCommand {
  _SkeletonTransformCommand(Float64List matrix4) : matrix4 = Float64List.fromList(matrix4);

  final Float64List matrix4;

  @override
  void replay(Canvas canvas, Paint paint) => canvas.transform(matrix4);
}
