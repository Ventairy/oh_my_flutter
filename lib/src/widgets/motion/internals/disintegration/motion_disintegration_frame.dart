part of '../../motion.dart';

class _MotionDisintegrationFrame {
  new({
    required _MotionDisintegrationSource source,
    required this.instance,
    required List<_MotionApplication> applications,
    required Duration stagger,
    required bool capturesBlurredSource,
    required this._devicePixelRatio,
    required this._maximumBlurOutset,
  }) : image = source.image,
       _sourceOutputBounds = source.outputBounds,
       _pixelRatio = source.pixelRatio,
       _applications = applications {
    painter = _MotionParticlePainter(
      image: image,
      applications: applications,
      fragments: source.fragments,
      stagger: stagger,
      sourceRegions: source.regions,
      characterIndices: source.characterIndices,
      capturesBlurredSource: capturesBlurredSource,
      blurFragments: applications.any((application) => application.effect is _TextMotionEffect),
      paintOffset: -_sourceOutputBounds.topLeft,
    );
  }

  final ui.Image image;
  final int instance;
  final Rect _sourceOutputBounds;
  final double _pixelRatio;
  final double _devicePixelRatio;
  final double _maximumBlurOutset;
  final List<_MotionApplication> _applications;

  static const channel = MethodChannel('dev.ventairy.oh_my_flutter.motion');
  static bool? _managedGaussianSupported;
  static Future<bool?>? _managedGaussianQuery;

  static Future<bool?> _queryManagedGaussianSupport() async {
    try {
      final supported = await channel.invokeMethod<bool>('supportsManagedGaussian');
      _managedGaussianSupported = supported;
      return supported;
    } on Exception {
      return null;
    } finally {
      _managedGaussianQuery = null;
    }
  }

  static bool get _supportsNativeDrawing =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        .android || .iOS => true,
        .fuchsia || .linux || .macOS || .windows => false,
      };
  static void release(int instance) {
    if (!_supportsNativeDrawing) return;
    unawaited(channel.invokeMethod<void>('releaseRenderer', {'instanceId': instance}).catchError((Object error) {}));
  }

  late final _MotionParticlePainter painter;
  var _frameParameters = Float64List(14);
  late var _lastDispatchedFrame = Float64List(_frameParameters.length);
  int? texture;
  int? handle;
  bool nativeFailed = false;
  bool _disposed = false;
  bool _playingNatively = false;
  bool _submitting = false;
  bool _frameChanged = false;
  bool _hasDispatchedFrame = false;
  ({Rect bounds, Size textureSize, bool skiaGaussian})? _gaussianOutput;
  _MotionTextureReadiness? _readiness;
  int _playbackGeneration = 0;

  bool get usesNative => texture != null && !nativeFailed;
  bool get usesNativeGaussian => usesNative && _gaussianOutput != null;
  Rect get outputBounds => usesNativeGaussian ? _gaussianOutput!.bounds : _sourceOutputBounds;

  int get _viewportWidth => (_sourceOutputBounds.width * _pixelRatio).ceil();
  int get _viewportHeight => (_sourceOutputBounds.height * _pixelRatio).ceil();
  Size get _textureSize =>
      _readiness?.size ?? _gaussianOutput?.textureSize ?? Size(_viewportWidth.toDouble(), _viewportHeight.toDouble());

  Future<void> prepare({required bool isText}) async {
    if (!isText && !painter.capturesBlurredSource) await _prepareNative(painter.singleOperations);
    if (!usesNative) painter.prepareGeometry();
  }

  void update({required bool tickersEnabled, required VoidCallback onNativeFailure}) {
    if (!usesNative || _disposed || _playingNatively) return;
    painter.updateOperations();
    final operations = painter.singleOperations;
    if (usesNativeGaussian && !_supportsGaussianSigma(operations._operations![2].blurSigma)) {
      _failNative();
      onNativeFailure();
      return;
    }
    final application = _applications.singleOrNull;
    final effect = application?.effect;
    final animation = application?.animation;
    final playback =
        !usesNativeGaussian &&
            effect is DisintegrateMotionEffect &&
            identical(effect.curve, Curves.linear) &&
            effect.playback.isOnce &&
            animation is _MotionAnimation &&
            animation._isRunning &&
            tickersEnabled
        ? _playNative(progress: animation.value, duration: effect.duration * (1 - animation.value))
        : _submitFrame(operations);
    unawaited(
      playback.then((_) {
        if (nativeFailed && !_disposed) onNativeFailure();
      }),
    );
  }

  Future<void> waitUntilReady() async {
    if (texture == null || _disposed) return;
    try {
      if (_readiness case final readiness?) {
        if (!await readiness.waitForImage()) _failNative();
        return;
      }
      await _MotionTextureReadiness.acquire(
        texture: texture!,
        size: _textureSize,
      );
      if (_disposed) return;
      await channel.invokeMethod<void>('awaitFirstFrame', _arguments).timeout(const Duration(seconds: 1));
    } on Exception {
      _failNative();
    }
  }

  Future<void> pause() async {
    if (_disposed || texture == null || nativeFailed || !_playingNatively) return;
    _playingNatively = false;
    _playbackGeneration++;
    try {
      await channel.invokeMethod<void>('pause', _arguments);
    } on Exception {
      _failNative();
    }
  }

  void dispose({bool outputRemoved = false}) {
    if (_disposed) return;
    _disposed = true;
    _readiness?.dispose();
    painter.dispose();
    image.dispose();
    if (texture != null) _releaseImage(retainOutput: outputRemoved && _readiness != null);
  }

  Widget buildNativeOutput({required double devicePixelRatio}) {
    final readiness = _readiness;
    final output = Texture(
      key: ValueKey(handle),
      textureId: texture!,
      filterQuality: readiness == null && _pixelRatio < devicePixelRatio ? .low : .none,
    );
    final textureSize = _textureSize / _pixelRatio;
    final textureWidth = textureSize.width;
    final textureHeight = textureSize.height;
    if (readiness == null && textureWidth == outputBounds.width && textureHeight == outputBounds.height) {
      return output;
    }
    return ClipRect(
      child: Stack(
        clipBehavior: .none,
        children: [
          Positioned(
            left: 0,
            top: -(readiness?.contentTop ?? 0) / _pixelRatio,
            width: textureWidth,
            height: textureHeight,
            child: output,
          ),
        ],
      ),
    );
  }

  Future<void> _prepareNative(MotionEffectTransform operations) async {
    if (!_supportsNativeDrawing || operations._operationCount != 3) return;
    try {
      if (defaultTargetPlatform == .iOS &&
          await channel.invokeMethod<bool>('prepareRenderer', const <String, Object?>{}) != true) {
        return;
      }
      final pixels = await image.toByteData();
      if (_disposed || pixels == null) return;
      _encodeFrame(operations);
      final arguments = <String, Object?>{
        'instanceId': instance,
        'image': pixels.buffer.asUint8List(pixels.offsetInBytes, pixels.lengthInBytes),
        'width': image.width,
        'height': image.height,
        'scaleX': 1.0,
        'scaleY': 1.0,
        'maximumParticleCount': _MotionDisintegrationParameters.maximumParticleCount,
        'minimumCellSize': operations._operations![1].particleSize * _pixelRatio,
        'seed': _MotionDisintegrationParameters.seed,
        'pointPadding': _MotionDisintegrationShaders.pointPadding,
        'geometryParameters': _MotionDisintegrationParameters.geometryParameters,
        'motionParameters': _MotionDisintegrationShaders.motionParameters,
        'vertexSource': _MotionDisintegrationShaders.vertex,
        'fragmentSource': _MotionDisintegrationShaders.fragment,
      };
      if (await _prepareGaussian(arguments, operations) || _disposed) return;
      _installOutput(await _prepareTexture(arguments, _frameParameters));
    } on Exception {
      _failNative();
    }
  }

  bool _supportsGaussianSigma(double sigma) =>
      sigma.isFinite &&
      sigma >= 0 &&
      sigma <= _MotionDisintegrationBounds._maximumNativeGaussianSigma &&
      _MotionBlur.outset(sigma) <= _maximumBlurOutset;

  Future<bool> _prepareGaussian(Map<String, Object?> arguments, MotionEffectTransform operations) async {
    final isAndroid = defaultTargetPlatform == .android;
    final supportsShaderFilter = ui.ImageFilter.isShaderFilterSupported;
    final skiaGaussian = isAndroid && !supportsShaderFilter;
    if (!supportsShaderFilter && !skiaGaussian) return false;
    // The Metal kernel reserves at most eight pixels of sigma in the captured texture.
    if (!isAndroid && _maximumBlurOutset * _pixelRatio > 3 * 8) return false;
    final sigma = operations._operations![2].blurSigma;
    var viewport = _MotionDisintegrationBounds.nativeGaussianViewport(
      outputSize: _sourceOutputBounds.size,
      capturePixelRatio: _pixelRatio,
      devicePixelRatio: _devicePixelRatio,
      blurOutset: _maximumBlurOutset,
      androidReadinessProbe: isAndroid,
      allowSkiaAndroid: skiaGaussian,
    );
    if (viewport == null || !_supportsGaussianSigma(sigma)) return false;

    late final Float64List frame;
    Map<String, Object?>? result;
    try {
      if (skiaGaussian) {
        final supportsManaged =
            _managedGaussianSupported ?? await (_managedGaussianQuery ??= _queryManagedGaussianSupport());
        // Null is an unanswered query. Only an explicit result can select a queue.
        if (_disposed || supportsManaged == null) return false;
        if (supportsManaged && viewport.legacyAndroid && _devicePixelRatio == 2) {
          // A managed texture adds a private readiness row to the small Skia viewport.
          final textureHeight = viewport.height + _MotionDisintegrationBounds._nativeGaussianProbeRows;
          if (textureHeight > _MotionDisintegrationBounds._maximumRasterDimension ||
              viewport.width * textureHeight > _MotionDisintegrationBounds._maximumLegacyGaussianPixels) {
            return false;
          }
          viewport = (
            padding: viewport.padding,
            width: viewport.width,
            height: viewport.height,
            legacyAndroid: false,
            fullDensityAndroid: true,
          );
        }
        if (supportsManaged != !viewport.legacyAndroid) return false;
      }
      frame = Float64List(16)..setAll(0, _frameParameters);
      _encodeGaussian(frame, sigma, skiaGaussian: skiaGaussian);
      result = await _prepareTexture(arguments, frame, gaussianViewport: viewport, skiaGaussian: skiaGaussian);
    } on Exception {
      // The regular texture and Flutter filter remain available.
      return false;
    }
    final androidReadinessProbe = isAndroid && !viewport.legacyAndroid;
    final expectedWidth = androidReadinessProbe
        ? math.max(viewport.width, _MotionTextureReadiness.androidProbeWidth)
        : viewport.width;
    final expectedHeight =
        viewport.height + (androidReadinessProbe ? _MotionDisintegrationBounds._nativeGaussianProbeRows : 0);
    final expectedProbe = androidReadinessProbe ? _MotionTextureReadiness.androidProbeWidth : null;
    final expectedContentTop = androidReadinessProbe ? _MotionDisintegrationBounds._nativeGaussianProbeRows : null;
    if (result
        case {
          'nativeGaussian': true,
          'textureId': int _,
          'handle': int _,
          'textureWidth': final int textureWidth,
          'textureHeight': final int textureHeight,
        }
        when textureWidth == expectedWidth &&
            textureHeight == expectedHeight &&
            (result['legacyGaussian'] == true) == viewport.legacyAndroid &&
            (result['fullDensityGaussian'] == true) == viewport.fullDensityAndroid &&
            result['probeWidth'] == expectedProbe &&
            result['contentTop'] == expectedContentTop) {
      final outset = viewport.padding / _pixelRatio;
      _gaussianOutput = (
        bounds: Rect.fromLTWH(
          _sourceOutputBounds.left - outset,
          _sourceOutputBounds.top - outset,
          viewport.width / _pixelRatio,
          viewport.height / _pixelRatio,
        ),
        textureSize: Size(textureWidth.toDouble(), textureHeight.toDouble()),
        skiaGaussian: skiaGaussian,
      );
      _frameParameters = frame;
      _installOutput(result);
      return true;
    }
    if (result case {'textureId': final int textureId, 'handle': final int imageHandle}) {
      _releaseImage(textureId: textureId, imageHandle: imageHandle);
    }
    return false;
  }

  Future<Map<String, Object?>?> _prepareTexture(
    Map<String, Object?> arguments,
    Float64List frame, {
    ({int padding, int width, int height, bool legacyAndroid, bool fullDensityAndroid})? gaussianViewport,
    bool skiaGaussian = false,
  }) {
    final padding = gaussianViewport?.padding ?? 0;
    return channel.invokeMapMethod<String, Object?>('prepare', {
      ...arguments,
      'viewportWidth': gaussianViewport?.width ?? _viewportWidth,
      'viewportHeight': gaussianViewport?.height ?? _viewportHeight,
      'originX': -_sourceOutputBounds.left * _pixelRatio + padding,
      'originY': -_sourceOutputBounds.top * _pixelRatio + padding,
      if (gaussianViewport != null) 'nativeGaussian': true,
      if (skiaGaussian) 'skiaGaussian': true,
      if (gaussianViewport?.legacyAndroid ?? false) 'legacyGaussian': true,
      if (gaussianViewport?.fullDensityAndroid ?? false) 'fullDensityGaussian': true,
      'frame': frame,
    });
  }

  void _installOutput(Map<String, Object?>? result) {
    if (result case {'textureId': final int textureId, 'handle': final int imageHandle}) {
      texture = textureId;
      handle = imageHandle;
      if (result case {
        'probeWidth': final int probeWidth,
        'textureWidth': final int textureWidth,
        'textureHeight': final int textureHeight,
        'contentTop': final int contentTop,
      }) {
        _readiness = _MotionTextureReadiness(
          texture: textureId,
          handle: imageHandle,
          size: Size(textureWidth.toDouble(), textureHeight.toDouble()),
          probeWidth: probeWidth,
          contentTop: contentTop.toDouble(),
        );
      }
      if (_disposed) _releaseImage();
    }
  }

  void _encodeFrame(MotionEffectTransform operations) {
    final before = operations._operations![0];
    final particles = operations._operations![1];
    final after = operations._operations![2];
    _frameParameters[0] = particles.progress;
    _frameParameters[1] = before.scale * before.cosine;
    _frameParameters[2] = before.scale * before.sine;
    _frameParameters[3] = before.x * _pixelRatio;
    _frameParameters[4] = before.y * _pixelRatio;
    _frameParameters[5] = after.scale * after.cosine;
    _frameParameters[6] = after.scale * after.sine;
    _frameParameters[7] = after.x * _pixelRatio;
    _frameParameters[8] = after.y * _pixelRatio;
    _frameParameters[9] = before.opacity.clamp(0.0, 1.0);
    _frameParameters[10] = after.opacity.clamp(0.0, 1.0);
    _frameParameters[11] = -(particles.directionX + particles.directionY) * math.sqrt(0.5);
    _frameParameters[12] = (particles.directionX - particles.directionY) * math.sqrt(0.5);
    _frameParameters[13] = particles.directionX == 0 && particles.directionY == 0 ? 0 : 1;
    if (usesNativeGaussian) {
      _encodeGaussian(_frameParameters, after.blurSigma, skiaGaussian: _gaussianOutput!.skiaGaussian);
    }
  }

  void _encodeGaussian(Float64List frame, double sigma, {required bool skiaGaussian}) {
    final fittedSigma = skiaGaussian ? sigma : sigma * (1 - 0.0034 * sigma + 0.0000034 * sigma * sigma);
    frame[14] = fittedSigma * _pixelRatio;
    frame[15] = fittedSigma * _devicePixelRatio;
  }

  Map<String, Object?> get _arguments => {'instanceId': instance, 'textureId': texture, 'handle': handle};

  void _recordDispatchedFrame() {
    final pending = _frameParameters;
    _frameParameters = _lastDispatchedFrame;
    _lastDispatchedFrame = pending;
    _hasDispatchedFrame = true;
  }

  Future<void> _submitFrame(MotionEffectTransform operations) async {
    if (_disposed || texture == null || nativeFailed || _playingNatively) return;
    _encodeFrame(operations);
    _frameChanged = true;
    if (_submitting) return;
    _submitting = true;
    try {
      while (_frameChanged && !_disposed && !nativeFailed && !_playingNatively) {
        _frameChanged = false;
        if (_hasDispatchedFrame && listEquals(_frameParameters, _lastDispatchedFrame)) continue;
        _recordDispatchedFrame();
        await channel.invokeMethod<void>('setFrame', {..._arguments, 'frame': _lastDispatchedFrame});
      }
    } on Exception {
      _failNative();
    } finally {
      _submitting = false;
    }
  }

  Future<void> _playNative({required double progress, required Duration duration}) async {
    if (_disposed || texture == null || nativeFailed || _playingNatively) return;
    _playingNatively = true;
    _frameChanged = false;
    _hasDispatchedFrame = false;
    final playback = ++_playbackGeneration;
    try {
      await channel.invokeMethod<void>('play', {
        ..._arguments,
        'fromProgress': progress.clamp(0.0, 1.0),
        'durationMillis': math.max(1, duration.inMilliseconds),
      });
    } on Exception {
      if (!_disposed && playback == _playbackGeneration) nativeFailed = true;
    } finally {
      if (playback == _playbackGeneration) _playingNatively = false;
    }
  }

  void _failNative() {
    nativeFailed = true;
    _frameChanged = false;
    if (_disposed || _gaussianOutput == null || texture == null) return;
    _releaseImage(retainOutput: true);
    texture = null;
    handle = null;
    _readiness?.dispose();
    _readiness = null;
  }

  void _releaseImage({bool retainOutput = false, int? textureId, int? imageHandle}) {
    final arguments = <String, Object?>{
      'instanceId': instance,
      'textureId': textureId ?? texture,
      'handle': imageHandle ?? handle,
    };
    if (retainOutput) arguments['retainOutput'] = true;
    unawaited(channel.invokeMethod<void>('dispose', arguments).catchError((Object error) {}));
  }
}
