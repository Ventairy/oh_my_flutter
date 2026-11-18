part of '../../motion.dart';

class _MotionDisintegrationFrame {
  new({
    required _MotionDisintegrationSource source,
    required this.instance,
    required List<_MotionApplication> applications,
    required Duration stagger,
  }) : image = source.image,
       outputBounds = source.outputBounds,
       _pixelRatio = source.pixelRatio,
       _applications = applications {
    painter = _MotionParticlePainter(
      image: image,
      applications: applications,
      fragments: source.fragments,
      stagger: stagger,
      sourceRegions: source.regions,
      paintOffset: -outputBounds.topLeft,
    );
  }

  final ui.Image image;
  final int instance;
  final Rect outputBounds;
  final double _pixelRatio;
  final List<_MotionApplication> _applications;

  static const channel = MethodChannel('dev.ventairy.oh_my_flutter.motion');

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
  final _frameParameters = Float64List(14);
  int? texture;
  int? handle;
  bool nativeFailed = false;
  bool _disposed = false;
  bool _playingNatively = false;
  bool _submitting = false;
  bool _frameChanged = false;
  _MotionTextureReadiness? _readiness;
  int _playbackGeneration = 0;

  bool get usesNative => texture != null && !nativeFailed;

  int get _viewportWidth => (outputBounds.width * _pixelRatio).ceil();
  int get _viewportHeight => (outputBounds.height * _pixelRatio).ceil();

  Future<void> prepare({required bool isText}) async {
    if (!isText) await _prepareNative(painter.singleOperations);
    if (!usesNative) painter.prepareGeometry();
  }

  void update({required bool tickersEnabled, required VoidCallback onNativeFailure}) {
    if (!usesNative || _disposed || _playingNatively) return;
    painter.updateOperations();
    final application = _applications.singleOrNull;
    final effect = application?.effect;
    final animation = application?.animation;
    final playback =
        effect is DisintegrateMotionEffect &&
            identical(effect.curve, Curves.linear) &&
            effect.playback.isOnce &&
            animation is _MotionAnimation &&
            animation._isRunning &&
            tickersEnabled
        ? _playNative(progress: animation.value, duration: effect.duration * (1 - animation.value))
        : _submitFrame(painter.singleOperations);
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
        nativeFailed = !await readiness.waitForImage();
        return;
      }
      await _MotionTextureReadiness.acquire(
        texture: texture!,
        size: Size(_viewportWidth.toDouble(), _viewportHeight.toDouble()),
      );
      if (_disposed) return;
      await channel.invokeMethod<void>('awaitFirstFrame', _arguments).timeout(const Duration(seconds: 1));
    } on Exception {
      nativeFailed = true;
    }
  }

  Future<void> pause() async {
    if (_disposed || texture == null || nativeFailed || !_playingNatively) return;
    _playingNatively = false;
    _playbackGeneration++;
    try {
      await channel.invokeMethod<void>('pause', _arguments);
    } on Exception {
      nativeFailed = true;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _readiness?.dispose();
    image.dispose();
    if (texture != null) _releaseImage();
  }

  Widget buildNativeOutput({required double devicePixelRatio}) {
    final readiness = _readiness;
    final output = Texture(
      key: ValueKey(handle),
      textureId: texture!,
      // Interpolation could bleed the Android probe row past its clip.
      filterQuality: readiness == null && _pixelRatio < devicePixelRatio ? .low : .none,
    );
    final textureWidth = (readiness?.size.width ?? _viewportWidth) / _pixelRatio;
    final textureHeight = (readiness?.size.height ?? _viewportHeight) / _pixelRatio;
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
      final result = await channel.invokeMapMethod<String, Object?>('prepare', {
        'instanceId': instance,
        'image': pixels.buffer.asUint8List(pixels.offsetInBytes, pixels.lengthInBytes),
        'width': image.width,
        'height': image.height,
        'viewportWidth': _viewportWidth,
        'viewportHeight': _viewportHeight,
        'originX': -outputBounds.left * _pixelRatio,
        'originY': -outputBounds.top * _pixelRatio,
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
        'frame': _frameParameters,
      });
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
    } on Exception {
      nativeFailed = true;
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
  }

  Map<String, Object?> get _arguments => {'instanceId': instance, 'textureId': texture, 'handle': handle};

  Future<void> _submitFrame(MotionEffectTransform operations) async {
    if (_disposed || texture == null || nativeFailed || _playingNatively) return;
    _encodeFrame(operations);
    _frameChanged = true;
    if (_submitting) return;
    _submitting = true;
    try {
      while (_frameChanged && !_disposed) {
        _frameChanged = false;
        await channel.invokeMethod<void>('setFrame', {..._arguments, 'frame': _frameParameters});
      }
    } on Exception {
      nativeFailed = true;
    } finally {
      _submitting = false;
    }
  }

  Future<void> _playNative({required double progress, required Duration duration}) async {
    if (_disposed || texture == null || nativeFailed || _playingNatively) return;
    _playingNatively = true;
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

  void _releaseImage() {
    unawaited(channel.invokeMethod<void>('dispose', _arguments).catchError((Object error) {}));
  }
}
