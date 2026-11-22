part of '../motion.dart';

/// Packs independently blurred glyphs into a shared filter pass. Uniformly
/// scaling a glyph changes its Gaussian sigma by the same factor, so the
/// packed texture can use one sigma and each result can be scaled back.
class _MotionPackedTextBlur {
  new(int glyphCount)
    : _slotByGlyph = Int32List(glyphCount),
      _inputTransforms = Float32List(4 * glyphCount),
      _inputRects = Float32List(4 * glyphCount),
      _outputTransforms = Float32List(4 * glyphCount),
      _outputRects = Float32List(4 * glyphCount),
      _outputColors = Int32List(glyphCount);

  static const double _wideSigma = 2.25;
  static const double _narrowSigma = 1.15;
  static const double _fineSigma = .65;
  static const double _maximumUpscale = 1.3;
  static const int _maximumDimension = 1024;
  static const int _maximumPixels = 256 * 1024;
  static const int minimumFilters = 4;
  final Int32List _slotByGlyph;
  final Float32List _inputTransforms;
  final Float32List _inputRects;
  final Float32List _outputTransforms;
  final Float32List _outputRects;
  final Int32List _outputColors;
  final Paint _widePaint = _packingPaint(_wideSigma);
  final Paint _narrowPaint = _packingPaint(_narrowSigma);
  final Paint _finePaint = _packingPaint(_fineSigma);
  late final Paint _separableFinePaint = _packingPaint(_MotionPackedFineFamily.sigma);
  _MotionPackedFineFamily? _fineFamily;
  _MotionPackedTextShelf? _shelf;
  bool _hasPackedSeparableFamily = false;

  static bool get _usesAndroidSkia =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && !ui.ImageFilter.isShaderFilterSupported;

  static Paint _packingPaint(double sigma) => Paint()
    ..filterQuality = FilterQuality.low
    ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);

  static double _sourceScale(double a, double b) => b == 0 ? a.abs() : math.sqrt(a * a + b * b);

  double _kernelSigma(Float64List sigmas, Float32List transforms) {
    var narrowRuns = 0;
    var fineRuns = 0;
    var canUseFine = true;
    var previous = 0.0;
    for (var index = 0; index < sigmas.length; index++) {
      final sigma = sigmas[index];
      if (sigma > 0) {
        final start = index * 4;
        final sourceScale = _sourceScale(transforms[start], transforms[start + 1]);
        if (sigma != previous &&
            sigma * _maximumUpscale >= _narrowSigma * sourceScale &&
            sigma < _wideSigma * sourceScale) {
          narrowRuns++;
        }
        // Keep full-resolution glyphs out of the fine pass and limit the
        // resampling it applies to glyphs that are still resolving.
        if (sourceScale > .5 || sigma > 4 * _fineSigma * sourceScale) {
          canUseFine = false;
        } else if (sigma != previous &&
            sigma * _maximumUpscale >= _fineSigma * sourceScale &&
            sigma < _narrowSigma * sourceScale) {
          fineRuns++;
        }
      }
      previous = sigma;
    }
    if (canUseFine && fineRuns >= 3) return _fineSigma;
    return narrowRuns >= 3 ? _narrowSigma : _wideSigma;
  }

  ui.Image? prepare(
    ui.Image atlas,
    Float64List sigmas,
    Float32List transforms,
    Float32List rects,
    Int32List? colors, {
    int shelfWidth = _maximumDimension,
  }) {
    final kernelSigma = _kernelSigma(sigmas, transforms);
    final isFine = kernelSigma == _fineSigma;
    final shelf = shelfWidth == _maximumDimension && !isFine && _usesAndroidSkia
        ? ((_shelf ??= _MotionPackedTextShelf(sigmas.length))..reset())
        : null;
    final maximumScale = kernelSigma == _wideSigma ? 1.0 : _maximumUpscale;
    final padding = _MotionBlur.outset(kernelSigma).toInt() + 2;
    _slotByGlyph.fillRange(0, _slotByGlyph.length, -1);
    var count = 0;
    var filterCount = 0;
    var previousSigma = 0.0;
    var left = 0;
    var top = 0;
    var width = 0;
    var rowHeight = 0;
    var exceedsBudget = false;
    for (var index = 0; index < sigmas.length; index++) {
      final sigma = sigmas[index];
      if (sigma == 0) {
        previousSigma = 0;
        continue;
      }

      final source = index * 4;
      final a = transforms[source];
      final b = transforms[source + 1];
      final scale = kernelSigma * _sourceScale(a, b) / sigma;
      // Avoid excessive upsampling and keep near-sharp glyphs on the
      // renderer's direct path.
      if (scale > maximumScale || scale <= 0 || !scale.isFinite) {
        previousSigma = 0;
        continue;
      }

      final tileWidth = ((rects[source + 2] - rects[source]) * scale).ceil() + padding * 2;
      final tileHeight = ((rects[source + 3] - rects[source + 1]) * scale).ceil() + padding * 2;
      shelf?.add(tileWidth, tileHeight);
      final nextRow = left + tileWidth > shelfWidth;
      final tileLeft = nextRow ? 0 : left;
      final tileTop = nextRow ? top + rowHeight : top;
      final nextHeight = nextRow ? tileHeight : math.max(rowHeight, tileHeight);
      final nextWidth = math.max(width, tileLeft + tileWidth);
      if (nextWidth > _maximumDimension ||
          tileTop + nextHeight > _maximumDimension ||
          nextWidth * (tileTop + nextHeight) > _maximumPixels) {
        exceedsBudget = true;
        previousSigma = 0;
        continue;
      }
      left = tileLeft;
      top = tileTop;
      rowHeight = nextHeight;
      width = nextWidth;

      if (sigma != previousSigma) filterCount++;
      previousSigma = sigma;
      _slotByGlyph[index] = count;
      final destination = count++ * 4;
      final outputA = a / scale;
      final outputB = b / scale;
      _inputTransforms[destination] = scale;
      _inputTransforms[destination + 2] = (left + padding).toDouble();
      _inputTransforms[destination + 3] = (top + padding).toDouble();
      _inputRects[destination] = rects[source];
      _inputRects[destination + 1] = rects[source + 1];
      _inputRects[destination + 2] = rects[source + 2];
      _inputRects[destination + 3] = rects[source + 3];
      _outputRects[destination] = left.toDouble();
      _outputRects[destination + 1] = top.toDouble();
      _outputRects[destination + 2] = (left + tileWidth).toDouble();
      _outputRects[destination + 3] = (top + tileHeight).toDouble();
      _outputTransforms[destination] = outputA;
      _outputTransforms[destination + 1] = outputB;
      _outputTransforms[destination + 2] = transforms[source + 2] + padding * (outputB - outputA);
      _outputTransforms[destination + 3] = transforms[source + 3] - padding * (outputB + outputA);
      if (colors != null) _outputColors[count - 1] = colors[index];
      left += tileWidth;
    }
    if (exceedsBudget && shelf != null) {
      // A narrower layout can avoid separate large filters with the same
      // allocation limits. Repack only when every eligible tile can fit.
      final narrowerWidth = shelf.fitWidth();
      if (narrowerWidth != null) {
        return prepare(atlas, sigmas, transforms, rects, colors, shelfWidth: narrowerWidth);
      }
    }
    if (filterCount < minimumFilters) return null;

    var height = top + rowHeight;
    // On Android Skia, the fine kernel otherwise compiles a separate
    // two-dimensional blur program near the end of the reveal.
    final canResize = isFine && _hasPackedSeparableFamily && _usesAndroidSkia;
    final resized = canResize
        ? (_fineFamily ??= _MotionPackedFineFamily(sigmas.length)).resize(this, sigmas, transforms, count: count)
        : null;
    if (resized != null) {
      width = resized.width;
      height = resized.height;
    }
    final recorder = ui.PictureRecorder();
    _MotionBlur.drawAtlasRange(
      Canvas(recorder),
      atlas,
      _inputTransforms,
      _inputRects,
      null,
      switch (kernelSigma) {
        _wideSigma => _widePaint,
        _narrowSigma => _narrowPaint,
        _ => resized == null ? _finePaint : _separableFinePaint,
      },
      start: 0,
      end: count,
    );
    final picture = recorder.endRecording();
    try {
      final image = picture.toImageSync(width, height);
      if (!isFine) _hasPackedSeparableFamily = true;
      return image;
    } finally {
      picture.dispose();
    }
  }

  bool includes(int glyph) => _slotByGlyph[glyph] >= 0;

  void paint(
    Canvas canvas,
    ui.Image image,
    Paint paint, {
    required int startGlyph,
    required int endGlyph,
    required bool usesOpacity,
  }) {
    _MotionBlur.drawAtlasRange(
      canvas,
      image,
      _outputTransforms,
      _outputRects,
      usesOpacity ? _outputColors : null,
      paint,
      start: _slotByGlyph[startGlyph],
      end: _slotByGlyph[endGlyph - 1] + 1,
    );
  }
}
