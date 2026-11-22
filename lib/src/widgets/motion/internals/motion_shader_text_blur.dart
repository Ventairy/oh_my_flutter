part of '../motion.dart';

/// Draws each blurred glyph directly from a suitable atlas resolution.
class _MotionShaderTextBlur {
  new(
    ui.FragmentProgram program,
    this._atlas, {
    required double paddingPixels,
    required bool useMesh,
  }) : _maximumSampleFactor = 2 * paddingPixels,
       _shader = useMesh ? null : program.fragmentShader(),
       _batch = useMesh ? _MotionVertexGlyphBatch(program) : null;

  static const double _minimumVariance = .0007;
  static const double _maximumVariance = 30 * 30;
  static ({ui.FragmentProgram program, bool useMesh})? prepared;
  static bool _warmUpRequested = false;

  static bool get _usesAndroidSkia =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && !ui.ImageFilter.isShaderFilterSupported;

  // Request preparation only after independent filters have actually been
  // needed. Loading the asset can ask the driver to compile, so starting at
  // layout could compete with an animation begun immediately after mounting.
  static void requestWarmUp({required double devicePixelRatio}) {
    if (_warmUpRequested) return;
    _warmUpRequested = true;
    // The Skia vertex path evaluates a runtime effect directly on the mesh.
    // Impeller would snapshot the shader first when texture coordinates are used.
    final useMesh = _usesAndroidSkia && Platform.isAndroid;
    final canvasScale = useMesh && devicePixelRatio.isFinite && devicePixelRatio >= 1 && devicePixelRatio <= 4
        ? devicePixelRatio
        : 1.0;
    _schedulePreparation(useMesh: useMesh, canvasScale: canvasScale);
  }

  static void _whenWarmUpReady(VoidCallback callback) {
    MotionShaderPreparation.schedule(callback, waitForQuiet: _usesAndroidSkia && Platform.isAndroid);
  }

  static void _schedulePreparation({required bool useMesh, double canvasScale = 1}) {
    _whenWarmUpReady(() => unawaited(_loadProgram(useMesh: useMesh, canvasScale: canvasScale)));
  }

  static Future<void> _loadProgram({required bool useMesh, required double canvasScale}) async {
    try {
      final asset = useMesh
          ? 'shaders/motion_glyph_blur_mesh.frag'
          : _usesAndroidSkia
          ? 'shaders/motion_glyph_blur_rows.frag'
          : 'shaders/motion_glyph_blur.frag';
      final program = await _loadAsset(asset);
      _whenWarmUpReady(() => unawaited(_preparePipeline(program, useMesh: useMesh, canvasScale: canvasScale)));
    } on Exception {
      if (useMesh) _schedulePreparation(useMesh: false);
    }
  }

  static Future<void> _preparePipeline(
    ui.FragmentProgram program, {
    required bool useMesh,
    required double canvasScale,
  }) async {
    try {
      if (await _warmUp(program, useMesh: useMesh, canvasScale: canvasScale)) {
        prepared = (program: program, useMesh: useMesh);
        return;
      }
    } on Exception {
      // The packed renderer stays available during preparation and if
      // neither runtime effect can be prepared.
    }
    if (useMesh) _schedulePreparation(useMesh: false);
  }

  static Future<ui.FragmentProgram> _loadAsset(String asset) async {
    try {
      return await ui.FragmentProgram.fromAsset('packages/oh_my_flutter/$asset');
    } on Exception {
      return await ui.FragmentProgram.fromAsset(asset);
    }
  }

  static Future<bool> _warmUp(
    ui.FragmentProgram program, {
    required bool useMesh,
    required double canvasScale,
  }) async {
    // The engine creates the graphics pipeline at the first raster draw, so
    // asset loading alone leaves that compilation on the animation's path.
    final atlasRecorder = ui.PictureRecorder();
    Canvas(atlasRecorder).drawRect(
      const Rect.fromLTWH(2, 2, 4, 4),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final atlasPicture = atlasRecorder.endRecording();
    final ui.Image atlas;
    try {
      atlas = atlasPicture.toImageSync(useMesh ? 9 : 8, 8);
    } finally {
      atlasPicture.dispose();
    }
    _MotionShaderTextBlur? blur;
    try {
      blur = _MotionShaderTextBlur(program, atlas, paddingPixels: 2, useMesh: useMesh);
      final inverseScale = 1 / canvasScale;
      final transforms = Float32List.fromList([inverseScale, 0, 4 * inverseScale, 4 * inverseScale]);
      final rects = Float32List.fromList([0, 0, 8, 8]);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      if (useMesh) {
        // An odd source width gives the mip copy a fractional edge, so
        // Skia prepares the coverage shader needed by real glyph atlases.
        canvas.save();
        blur._scaleAndDrawMip(canvas, atlas);
        canvas.restore();
      }
      // Skia keys mesh programs by transform type. Match the view while
      // keeping the sample glyph and sigma at the same physical scale.
      if (canvasScale != 1) canvas.scale(canvasScale);
      // Exercise both kernel sizes with the same shader paint and blend mode
      // used for onscreen glyphs. Await rasterization before enabling the path.
      blur
        ..paint(canvas, transforms, rects, 0, .7 * inverseScale, .8, level: 0)
        ..paint(canvas, transforms, rects, 0, 1.4 * inverseScale, .8, level: 0)
        ..flush(canvas);
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(16, 16);
        image.dispose();
      } finally {
        picture.dispose();
      }
      return blur.available;
    } finally {
      blur?.dispose();
      atlas.dispose();
    }
  }

  final ui.Image _atlas;
  final double _maximumSampleFactor;
  final ui.FragmentShader? _shader;
  final _MotionVertexGlyphBatch? _batch;
  final List<ui.Image> _mips = [];
  final Paint _blurPaint = Paint()..isAntiAlias = false;
  final Paint _mipPaint = Paint()..filterQuality = FilterQuality.low;
  int _boundLevel = -1;
  bool available = true;
  Int32List? _levels;

  void flush(Canvas canvas) => _batch?.flush(canvas);

  bool prepare(Float32List transforms, Float32List rects, Float64List sigmas) {
    if (_levels?.length != sigmas.length) _levels = Int32List(sigmas.length);
    final levels = _levels!;
    var hasShaderWork = false;
    var rejectedRuns = 0;
    var previousRejectedSigma = 0.0;
    for (var glyph = 0; glyph < sigmas.length; glyph++) {
      final sigma = sigmas[glyph];
      final level = sigma > 0 ? _levelForGlyph(transforms, rects, glyph * 4, sigma) : -1;
      levels[glyph] = level;
      if (level >= 0) {
        hasShaderWork = true;
        previousRejectedSigma = 0;
      } else {
        if (sigma > 0 && sigma != previousRejectedSigma && ++rejectedRuns >= _MotionPackedTextBlur.minimumFilters) {
          return false;
        }
        previousRejectedSigma = sigma;
      }
    }
    return hasShaderWork;
  }

  int sampleLevel(int glyph) => _levels![glyph];

  int _levelForGlyph(Float32List transforms, Float32List rects, int start, double sigma) {
    final a = transforms[start];
    final b = transforms[start + 1];
    final variance = (sigma * sigma) / (a * a + b * b);
    if (!variance.isFinite || variance < _minimumVariance || variance > _maximumVariance) return -1;
    var level = 0;
    var factor = 1;
    while (variance >= factor * factor * 4) {
      level++;
      factor *= 2;
    }

    // Keep each mip texel's footprint within the atlas padding around a glyph.
    if (factor > _maximumSampleFactor ||
        rects[start + 2] - rects[start] < 2 * factor ||
        rects[start + 3] - rects[start + 1] < 2 * factor) {
      return -1;
    }
    return level;
  }

  bool paint(
    Canvas canvas,
    Float32List transforms,
    Float32List rects,
    int glyph,
    double sigma,
    double opacity, {
    required int level,
  }) {
    if (!available) return false;
    final start = glyph * 4;
    final a = transforms[start];
    final b = transforms[start + 1];
    final scaleSquared = a * a + b * b;
    final sourceSigma = sigma / math.sqrt(scaleSquared);
    final factor = (1 << level).toDouble();
    final left = rects[start] / factor;
    final top = rects[start + 1] / factor;
    final right = rects[start + 2] / factor;
    final bottom = rects[start + 3] / factor;

    // A mip's box filter supplies part of the blur variance. Convolve with
    // the remainder at that resolution instead of taking widely spaced taps.
    final variance = (sourceSigma * sourceSigma - (factor * factor - 1) / 12) / (factor * factor);
    final weight1 = math.exp(-.5 / variance);
    final weight2 = math.exp(-2 / variance);
    final innerWeight = weight1 + weight2;
    if (innerWeight <= 0) return false;
    final weight3 = variance < .64 ? 0.0 : math.exp(-4.5 / variance);
    final weight4 = variance < .64 ? 0.0 : math.exp(-8 / variance);
    final outerWeight = weight3 + weight4;
    final normalized = 1 / (1 + 2 * (innerWeight + outerWeight));
    final x = transforms[start + 2];
    final y = transforms[start + 3];
    final width = rects[start + 2] - rects[start];
    final height = rects[start + 3] - rects[start + 1];
    final across = a * width;
    final down = b * height;
    final rightSide = b * width;
    final bottomSide = a * height;
    final spread = _MotionBlur.outset(sigma) + 1;
    final clipped = Rect.fromLTRB(
      x + math.min(0, across) - math.max(0, down) - spread,
      y + math.min(0, rightSide) + math.min(0, bottomSide) - spread,
      x + math.max(0, across) - math.min(0, down) + spread,
      y + math.max(0, rightSide) + math.max(0, bottomSide) + spread,
    );
    final batch = _batch;
    if (batch != null && !(clipped.width < _MotionVertexGlyphBatch.maximumGlyphWidth)) return false;
    final ui.Image image;
    try {
      image = _mipAt(level);
    } on ui.PictureRasterizationException {
      available = false;
      return false;
    }

    final ui.FragmentShader shader;
    final int firstParameter;
    if (batch != null) {
      firstParameter = batch.add(canvas, image, clipped);
      shader = batch.shader;
    } else {
      shader = _shader!;
      firstParameter = 2;
      if (_boundLevel != level) {
        _boundLevel = level;
        shader
          ..setImageSampler(0, image, filterQuality: FilterQuality.low)
          ..setFloat(0, image.width.toDouble())
          ..setFloat(1, image.height.toDouble());
      }
    }

    shader
      ..setFloat(firstParameter, x)
      ..setFloat(firstParameter + 1, y)
      ..setFloat(firstParameter + 2, a / (scaleSquared * factor))
      ..setFloat(firstParameter + 3, b / (scaleSquared * factor))
      ..setFloat(firstParameter + 4, left)
      ..setFloat(firstParameter + 5, top)
      ..setFloat(firstParameter + 6, right)
      ..setFloat(firstParameter + 7, bottom)
      ..setFloat(firstParameter + 8, normalized)
      ..setFloat(firstParameter + 9, weight1 * normalized)
      ..setFloat(firstParameter + 10, weight2 * normalized)
      ..setFloat(firstParameter + 11, weight3 * normalized)
      ..setFloat(firstParameter + 12, weight4 * normalized)
      ..setFloat(firstParameter + 13, opacity);

    if (batch != null) return true;
    try {
      canvas.drawRect(clipped, _blurPaint..shader = shader);
      return true;
    } on ui.PictureRasterizationException {
      available = false;
      return false;
    }
  }

  ui.Image _mipAt(int level) {
    if (level == 0) return _atlas;
    while (_mips.length < level) {
      final source = _mips.isEmpty ? _atlas : _mips.last;
      final recorder = ui.PictureRecorder();
      _scaleAndDrawMip(Canvas(recorder), source);
      final picture = recorder.endRecording();
      try {
        _mips.add(picture.toImageSync((source.width + 1) ~/ 2, (source.height + 1) ~/ 2));
      } finally {
        picture.dispose();
      }
    }
    return _mips[level - 1];
  }

  void _scaleAndDrawMip(Canvas canvas, ui.Image source) {
    canvas
      ..scale(.5)
      ..drawImage(source, Offset.zero, _mipPaint);
  }

  void dispose() {
    _blurPaint.shader = null;
    _shader?.dispose();
    _batch?.dispose();
    for (final image in _mips) {
      image.dispose();
    }
  }
}
