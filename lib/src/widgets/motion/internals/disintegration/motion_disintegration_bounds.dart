part of '../../motion.dart';

abstract final class _MotionDisintegrationBounds {
  static const int _maximumRasterPixels = 512 * 1024;
  static const _maximumRasterDimension = 2048;

  static double capturePixelRatio({
    required Size sourceSize,
    required Size outputSize,
    required double devicePixelRatio,
    required bool androidReadinessProbe,
  }) {
    bool fits(double ratio) {
      final sourceWidth = (sourceSize.width * ratio).ceil();
      final sourceHeight = (sourceSize.height * ratio).ceil();
      final outputWidth = (outputSize.width * ratio).ceil();
      final outputHeight = (outputSize.height * ratio).ceil();
      final textureWidth = androidReadinessProbe
          ? math.max(_MotionTextureReadiness.androidProbeWidth, outputWidth)
          : outputWidth;
      final textureHeight = androidReadinessProbe ? outputHeight + 1 : outputHeight;
      return sourceWidth <= _maximumRasterDimension &&
          sourceHeight <= _maximumRasterDimension &&
          sourceWidth * sourceHeight <= _maximumRasterPixels &&
          textureWidth <= _maximumRasterDimension &&
          textureHeight <= _maximumRasterDimension &&
          textureWidth * textureHeight <= _maximumRasterPixels;
    }

    if (fits(devicePixelRatio)) return devicePixelRatio;
    var floor = 0.0;
    var ceiling = devicePixelRatio;
    // Test the rounded pixel dimensions, including the Android readiness row.
    for (var step = 0; step < 24; step++) {
      final candidate = (floor + ceiling) / 2;
      if (fits(candidate)) {
        floor = candidate;
      } else {
        ceiling = candidate;
      }
    }
    return floor;
  }

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
