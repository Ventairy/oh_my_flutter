part of '../../motion.dart';

abstract final class _MotionDisintegrationBounds {
  static const int _maximumRasterPixels = 512 * 1024;
  static const _maximumRasterDimension = 2048;
  static const int _maximumNativeGaussianPixels = 640 * 1024;
  static const int _minimumLegacyGaussianPixels = 192 * 1024;
  static const double _legacyGaussianSplitSigma = 4 / .999;
  static const double _fullDensityGaussianSplitSigma = 8 / .9;
  static const int _maximumLegacyGaussianPixels = 320 * 1024;
  static const _nativeGaussianProbeRows = 1;
  static const _maximumNativeGaussianSigma = 4.0;

  static ({int padding, int width, int height, bool legacyAndroid, bool fullDensityAndroid})? nativeGaussianViewport({
    required Size outputSize,
    required double capturePixelRatio,
    required double devicePixelRatio,
    required double blurOutset,
    required bool androidReadinessProbe,
    required bool allowSkiaAndroid,
  }) {
    if (blurOutset <= 0 || blurOutset > _MotionBlur.outset(_maximumNativeGaussianSigma)) return null;
    final managedDensity =
        devicePixelRatio >= capturePixelRatio * 1.5 &&
        outputSize.width * outputSize.height * devicePixelRatio * devicePixelRatio >= 1500000;
    // The rounded halo must imply a peak large enough to enter the native reduced grid.
    final minimumPeakSigma = (blurOutset - 1) * capturePixelRatio / 3;
    final legacyAndroid =
        !managedDensity &&
        allowSkiaAndroid &&
        devicePixelRatio == capturePixelRatio &&
        devicePixelRatio <= 2 &&
        minimumPeakSigma >= _legacyGaussianSplitSigma;
    final fullDensityAndroid =
        allowSkiaAndroid &&
        devicePixelRatio == capturePixelRatio &&
        devicePixelRatio <= 3 &&
        minimumPeakSigma > _fullDensityGaussianSplitSigma;
    if (!managedDensity && !legacyAndroid && !fullDensityAndroid) return null;
    final padding = (blurOutset * capturePixelRatio).ceil();
    final width = (outputSize.width * capturePixelRatio).ceil() + padding * 2;
    final height = (outputSize.height * capturePixelRatio).ceil() + padding * 2;
    final needsProbe = androidReadinessProbe && !legacyAndroid;
    final textureWidth = needsProbe ? math.max(width, _MotionTextureReadiness.androidProbeWidth) : width;
    final textureHeight = height + (needsProbe ? _nativeGaussianProbeRows : 0);
    final pixels = textureWidth * textureHeight;
    if (textureWidth > _maximumRasterDimension ||
        textureHeight > _maximumRasterDimension ||
        pixels > _maximumNativeGaussianPixels) {
      return null;
    }
    if (legacyAndroid && (pixels < _minimumLegacyGaussianPixels || pixels > _maximumLegacyGaussianPixels)) {
      return null;
    }
    if (fullDensityAndroid && pixels < _maximumRasterPixels) return null;
    return (
      padding: padding,
      width: width,
      height: height,
      legacyAndroid: legacyAndroid,
      fullDensityAndroid: fullDensityAndroid,
    );
  }

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

  static Rect calculate({
    required Size size,
    required List<Rect> fragments,
    required List<MotionEffect> effects,
    required double blurOutset,
  }) {
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
        includeBlur: false,
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
    bounds = bounds.inflate(blurOutset);
    return Rect.fromLTRB(
      bounds.left.floorToDouble(),
      bounds.top.floorToDouble(),
      bounds.right.ceilToDouble(),
      bounds.bottom.ceilToDouble(),
    );
  }
}
