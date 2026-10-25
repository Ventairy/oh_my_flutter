part of 'contour.dart';

class _ContourShadowAtlas {
  new(this.onReady);

  static const int _maximumPixels = 256 * 1024;
  static const int frames = 9;
  static const double interval = 8;
  static const int _density = 3;
  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram>? _loadingProgram;

  final VoidCallback onReady;
  final Paint _paint = Paint();
  Timer? _timer;
  int? _frameCallbackId;
  bool _framePending = false;
  _ContourImageResource? _resource;
  _ContourShadowAtlasKey? _key;
  ui.FragmentShader? _shader;
  Rect _bounds = Rect.zero;
  int _revision = 0;
  int _running = 0;
  int buildCount = 0;
  int paintCount = 0;

  bool get ready => _resource?.image != null && _shader != null;
  bool get generating => _timer != null || _framePending || _running > 0;
  int get resourceId => _resource?.id ?? 0;
  double get minimumAmount => _key?.minimumAmount ?? 0;
  double get maximumAmount => minimumAmount + interval;
  bool contains(double amount) => _key != null && amount >= minimumAmount && amount <= maximumAmount;

  void invalidate() {
    _revision++;
    _timer?.cancel();
    _timer = null;
    if (_frameCallbackId case final int id) SchedulerBinding.instance.cancelFrameCallbackWithId(id);
    _frameCallbackId = null;
    _framePending = false;
    _key = null;
    _shader?.dispose();
    _shader = null;
    final resource = _resource;
    _resource = null;
    if (resource != null) _ContourImagePool.release(resource);
  }

  bool schedule({
    required _ContourShadowAtlasKey key,
    required Rect bounds,
    required Rect shapeBounds,
    required double maskMargin,
    required List<Shadow> shadows,
    required int sourceBytes,
    required bool Function() isCurrentSource,
    required ui.Picture Function(double amount) recordMask,
  }) {
    if (_key == key) return true;
    invalidate();
    if (bounds.isEmpty || !bounds.isFinite) return false;
    final tileWidth = bounds.width.ceil();
    final tileHeight = bounds.height.ceil();
    // Reject dimensions before integer products can overflow for large amounts.
    if (tileWidth > 2048 ~/ (3 * _density) || tileHeight > 2048 ~/ (3 * _density)) return false;
    final width = tileWidth * 3;
    final height = tileHeight * 3;
    final pixels = width * height;
    if (pixels > _maximumPixels) return false;
    if (sourceBytes * frames > _ContourShadowAtlasSource._maximumBytes) return false;
    _key = key;
    _bounds = Rect.fromLTWH(bounds.left, bounds.top, tileWidth.toDouble(), tileHeight.toDouble());
    final revision = _revision;
    final existing = _ContourImagePool.retainExisting(key);
    if (existing != null) {
      _resource = existing;
      unawaited(_waitFor(existing, revision));
      return true;
    }
    // Amount updates in the same interval do not restart this source debounce.
    // The queue dispatches after build, so a changed source cancels its request
    // before recording or uploading obsolete artwork.
    _timer = Timer(const Duration(milliseconds: 120), () {
      _timer = null;
      // A source can change between frames before its composition invalidates
      // the old proof. Validate that next frame before freezing its masks.
      _framePending = true;
      _frameCallbackId = SchedulerBinding.instance.scheduleFrameCallback((_) {
        _frameCallbackId = null;
        if (_revision != revision) return;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (_revision != revision) return;
          _framePending = false;
          // An earlier post-frame callback may have changed a native paragraph
          // after composition. Let another valid owner claim the key instead.
          if (!isCurrentSource()) {
            _key = null;
            return;
          }
          final claim = _ContourImagePool.obtainImage(
            key: key,
            bounds: _bounds,
            ratio: 1,
            width: width,
            height: height,
            pixels: pixels,
            build: (resource) {
              // This callback runs synchronously until the queue await. Freeze the
              // mask before retaining any asynchronous work: native painters and
              // their source widgets may change or detach while followers wait.
              final source = _ContourShadowAtlasSource.record(
                minimumAmount: key.minimumAmount,
                sourceBytes: sourceBytes,
                recordMask: recordMask,
              );
              if (source == null) return Future<ui.Image?>.value();
              return _generate(
                resource: resource,
                source: source,
                pixels: pixels,
                minimumAmount: key.minimumAmount,
                shapeBounds: shapeBounds,
                maskMargin: maskMargin,
                shadows: shadows,
                bounds: bounds,
                tileWidth: tileWidth,
                tileHeight: tileHeight,
              );
            },
          );
          if (claim.resource case final _ContourImageResource resource) {
            _resource = resource;
            if (claim.owner) buildCount++;
            unawaited(_waitFor(resource, revision));
          } else {
            _key = null;
          }
        });
      });
    });
    return true;
  }

  static Future<ui.Image?> _generate({
    required _ContourImageResource resource,
    required _ContourShadowAtlasSource source,
    required int pixels,
    required double minimumAmount,
    required Rect shapeBounds,
    required double maskMargin,
    required List<Shadow> shadows,
    required Rect bounds,
    required int tileWidth,
    required int tileHeight,
  }) async {
    try {
      resource.cancelQueued = () => _ContourAtlasQueue.cancel(resource);
      return await _ContourAtlasQueue.run(
        owner: resource,
        transientPixels: pixels * (2 * _density * _density + 2),
        isCurrent: () => resource.references > 0,
        build: () => _buildAtlas(
          source: source,
          minimumAmount: minimumAmount,
          shapeBounds: shapeBounds,
          maskMargin: maskMargin,
          shadows: shadows,
          bounds: bounds,
          tileWidth: tileWidth,
          tileHeight: tileHeight,
        ),
      );
    } finally {
      source.dispose();
    }
  }

  Future<void> _waitFor(_ContourImageResource resource, int revision) async {
    _running++;
    ui.FragmentShader? shader;
    try {
      final image = await resource.completion.future;
      if (_revision != revision || !identical(_resource, resource)) return;
      if (image == null) {
        invalidate();
        return;
      }
      final program = _program ??= await (_loadingProgram ??= _loadProgram());
      _loadingProgram = null;
      if (_revision != revision || !identical(_resource, resource)) return;
      shader = program.fragmentShader()..setImageSampler(0, image, filterQuality: FilterQuality.low);
      _shader = shader;
      shader = null;
      onReady();
    } catch (error, stack) {
      if (_revision == revision) invalidate();
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'Contour'));
    } finally {
      shader?.dispose();
      _running--;
    }
  }

  static Future<ui.FragmentProgram> _loadProgram() async {
    try {
      return await ui.FragmentProgram.fromAsset('packages/oh_my_flutter/shaders/contour_shadow_atlas.frag');
    } on Exception {
      // A consumer bundles package assets under their qualified paths. When
      // this package is the root project, Flutter bundles the same shader
      // directly under shaders/ instead.
      return await ui.FragmentProgram.fromAsset('shaders/contour_shadow_atlas.frag');
    }
  }

  static Future<ui.Image> _buildAtlas({
    required _ContourShadowAtlasSource source,
    required double minimumAmount,
    required Rect shapeBounds,
    required double maskMargin,
    required List<Shadow> shadows,
    required Rect bounds,
    required int tileWidth,
    required int tileHeight,
  }) async {
    final paints = [
      for (final shadow in shadows)
        Paint()
          ..colorFilter = ColorFilter.mode(shadow.color, BlendMode.srcIn)
          ..imageFilter = ui.ImageFilter.blur(sigmaX: shadow.blurSigma, sigmaY: shadow.blurSigma),
    ];
    final recorder = ui.PictureRecorder();
    try {
      final canvas = Canvas(recorder)..scale(_density.toDouble());
      for (var index = 0; index < frames; index++) {
        canvas
          ..save()
          ..translate((index % 3 * tileWidth).toDouble(), (index ~/ 3 * tileHeight).toDouble())
          ..clipRect(Rect.fromLTWH(0, 0, tileWidth.toDouble(), tileHeight.toDouble()))
          ..translate(-bounds.left, -bounds.top);
        final maskBounds = shapeBounds.inflate(minimumAmount + index + maskMargin);
        for (var shadowIndex = 0; shadowIndex < shadows.length; shadowIndex++) {
          final shadow = shadows[shadowIndex];
          canvas
            ..save()
            ..translate(shadow.offset.dx, shadow.offset.dy)
            ..saveLayer(maskBounds.inflate(shadow.blurSigma * 3), paints[shadowIndex])
            ..drawPicture(source.pictures[index])
            ..restore()
            ..restore();
        }
        canvas.restore();
      }
    } catch (_) {
      recorder.endRecording().dispose();
      rethrow;
    }
    return await const ContourShadowAtlasRasterizer().rasterize(
      picture: recorder.endRecording(),
      width: tileWidth * 3 * _density,
      height: tileHeight * 3 * _density,
      outputWidth: tileWidth * 3,
      outputHeight: tileHeight * 3,
    );
  }

  bool paint(Canvas canvas, double amount) {
    if (!ready || !contains(amount)) return false;
    final image = _resource!.image!;
    final localAmount = amount - minimumAmount;
    final low = localAmount.floor().clamp(0, frames - 2);
    final shader = _shader!
      ..setFloat(0, _bounds.left)
      ..setFloat(1, _bounds.top)
      ..setFloat(2, _bounds.width)
      ..setFloat(3, _bounds.height)
      ..setFloat(4, image.width.toDouble())
      ..setFloat(5, image.height.toDouble())
      ..setFloat(6, low.toDouble())
      ..setFloat(7, localAmount - low)
      ..setFloat(8, 3)
      ..setFloat(9, 8)
      ..setFloat(10, 1);
    _paint.shader = shader;
    canvas.drawRect(_bounds, _paint);
    paintCount++;
    return true;
  }
}
