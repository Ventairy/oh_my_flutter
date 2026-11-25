part of '../../motion.dart';

class _MotionParticleBlurredSource {
  new({
    required ui.Image image,
    required _MotionParticleFragment fragment,
    required this.budget,
    required this.isWidget,
  }) : _original = _MotionParticleRaster(image, fragment);

  final int budget;
  final bool isWidget;
  final _MotionParticleRaster _original;
  final _started = <int, _MotionParticleRaster?>{};
  final _loopPhases = <int, double>{};
  final _blur = _MotionBlur();
  final _paint = Paint();

  void paint(Canvas canvas) {
    final operations = _original.fragment.operations;
    final count = operations._operationCount;
    final values = operations._operations!;
    for (var index = 1; index < count; index += 2) {
      final operation = values[index];
      final previousPhase = _loopPhases[index];
      final phase = operation.loopPhase;
      final looped = phase != null && previousPhase != null && phase < previousPhase;
      if (phase != null) _loopPhases[index] = phase;
      if (looped || operation.progress == 0) {
        final removed = _started.remove(index);
        removed?.dispose();
        removed?.image.dispose();
      }
    }

    var raster = _original;
    var sigma = 0.0;
    for (var index = 0; index < count; index += 2) {
      final transform = values[index];
      sigma = _MotionBlur.combine(sigma * transform.scale.abs(), transform.blurSigma);
      final stage = index + 1;
      if (stage >= count || values[stage].progress == 0) continue;
      if (!_started.containsKey(stage)) {
        _started[stage] = sigma == 0 ? null : _capture(raster, stage, sigma);
      }
      raster = _started[stage] ?? raster;
      sigma = 0;
    }

    if (!raster.prepare(allowPruning: isWidget && sigma == 0)) return;
    _paint.imageFilter = sigma == 0 ? null : _blur.filter(sigma);
    raster.paint(canvas, _paint);
  }

  _MotionParticleRaster? _capture(_MotionParticleRaster raster, int stage, double sigma) {
    if (!raster.prepare(end: stage)) return null;
    final visible = raster.visibleBounds();
    if (visible == null) return null;

    final bounds = visible.inflate(_MotionBlur.outset(sigma));
    final source = _original.fragment;
    final ratio = _MotionDisintegrationBounds.capturePixelRatio(
      sourceSize: bounds.size,
      outputSize: bounds.size,
      devicePixelRatio: source.sourceRegion.width / source.bounds.width,
      androidReadinessProbe: false,
    );
    if (ratio <= 0) return null;
    final fullWidth = (bounds.width * ratio).ceil();
    final fullHeight = (bounds.height * ratio).ceil();
    // Keep at least four texels per Gaussian sigma in the smaller snapshot.
    final halfResolution =
        isWidget && stage == 1 && source.operations._operationCount == 3 && ratio >= 2 && sigma * ratio >= 8;
    final sampleScale = halfResolution ? 0.5 : 1.0;
    final sampleWidth = fullWidth * sampleScale;
    final sampleHeight = fullHeight * sampleScale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(ratio)
      ..translate(-bounds.left, -bounds.top);
    final gaussian = _blur.filter(sigma);
    if (halfResolution) {
      // Scale the filtered output around the snapshot's top-left corner.
      final half = Matrix4.diagonal3Values(0.5, 0.5, 1)..setTranslationRaw(bounds.left * 0.5, bounds.top * 0.5, 0);
      _paint.imageFilter = ui.ImageFilter.compose(
        inner: gaussian,
        outer: ui.ImageFilter.matrix(half.storage, filterQuality: FilterQuality.low),
      );
    } else {
      _paint.imageFilter = gaussian;
    }
    raster.paint(canvas, _paint);
    final picture = recorder.endRecording();
    final ui.Image image;
    try {
      image = picture.toImageSync(sampleWidth.ceil(), sampleHeight.ceil());
    } finally {
      picture.dispose();
    }
    return _MotionParticleRaster(
      image,
      _MotionParticleFragment(
        bounds: Rect.fromLTWH(bounds.left, bounds.top, fullWidth / ratio, fullHeight / ratio),
        operations: source.operations,
        budget: budget,
        firstParticle: 0,
        sourceRegion: Rect.fromLTWH(0, 0, sampleWidth, sampleHeight),
        firstOperation: stage,
        pivot: source._pivot,
      ),
      filterQuality: halfResolution ? FilterQuality.low : FilterQuality.none,
    );
  }

  void dispose() {
    _original.dispose();
    for (final raster in _started.values) {
      raster?.dispose();
      raster?.image.dispose();
    }
    _started.clear();
  }
}
