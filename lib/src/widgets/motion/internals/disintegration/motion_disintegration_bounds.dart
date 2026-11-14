part of '../../motion.dart';

abstract final class _MotionDisintegrationBounds {
  static Rect calculate({required Size size, required List<Rect> fragments, required List<MotionEffect> effects}) {
    final operations = MotionEffectTransform._();
    final pivot = size.center(Offset.zero);
    final sourceBounds = fragments.fold<Rect>(
      Offset.zero & size,
      (bounds, fragment) => bounds.expandToInclude(fragment),
    );
    var bounds = sourceBounds.expandToInclude(
      _MotionRenderEffect.paintBoundsFor(
        size,
        effects
            .map((effect) => effect is _TextMotionEffect ? effect.effect.bounds : effect.bounds)
            .whereType<MotionEffectBounds>(),
      ),
    );
    final matrix = Matrix4.identity();
    for (var sample = 0; sample <= _MotionRenderEffect._boundsSampleCount; sample++) {
      operations._reset();
      for (final effect in effects) {
        final source = effect is _TextMotionEffect ? effect.effect : effect;
        source.apply(source.curve.transform(sample / _MotionRenderEffect._boundsSampleCount), operations);
      }
      operations._finishOperations();
      var frameBounds = sourceBounds;
      for (var index = 0; index < operations._operationCount; index++) {
        final operation = operations._operations![index];
        if (operation.kind == .disintegrate) {
          if (operation.directionX != 0 || operation.directionY != 0) {
            frameBounds = frameBounds.inflate(size.width * 0.15);
          }
          continue;
        }
        final a = operation.scale * operation.cosine;
        final b = operation.scale * operation.sine;
        matrix.setIdentity();
        matrix.storage[0] = a;
        matrix.storage[1] = b;
        matrix.storage[4] = -b;
        matrix.storage[5] = a;
        matrix.storage[12] = pivot.dx * (1 - a) + pivot.dy * b + operation.x;
        matrix.storage[13] = pivot.dy * (1 - a) - pivot.dx * b + operation.y;
        frameBounds = MatrixUtils.transformRect(matrix, frameBounds);
      }
      bounds = bounds.expandToInclude(frameBounds);
    }
    return Rect.fromLTRB(
      bounds.left.floorToDouble(),
      bounds.top.floorToDouble(),
      bounds.right.ceilToDouble(),
      bounds.bottom.ceilToDouble(),
    );
  }
}
