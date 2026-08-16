part of 'morph.dart';

class _MorphTextRasterCache extends ChangeNotifier {
  static const int _maximumRasterDimension = 2048;
  static const int _maximumRasterPixels = 1024 * 1024;

  final TextPainter _painter = TextPainter();
  final Paint _rasterPaint = Paint()..filterQuality = FilterQuality.low;
  _MorphTextRasterPool? rasterPool;

  ui.Image? _image;
  _MorphTextRasterPoolLease? _imageLease;
  Future<ui.Image>? _pendingImage;
  Future<bool>? _rasterRetry;
  VoidCallback? _retryCancellation;
  int _retryGeneration = 0;
  MorphTextProperties? _imageProperties;
  TextStyle? _imageRasterStyle;
  double? _imageLayoutWidth;
  double? _imageDevicePixelRatio;
  double? _imageViewDevicePixelRatio;
  double? _imageMaximumScale;
  double _imagePadding = 0;
  double _rasterHeight = 0;
  List<ui.LineMetrics> _rasterLineMetrics = const <ui.LineMetrics>[];
  double _paintedHeight = 0;
  List<ui.LineMetrics> _paintedLineMetrics = const <ui.LineMetrics>[];
  TextStyle? _paintedStyle;
  Color? _paintedColor;
  int? _imageSegment;
  bool _imageDisabledForSegment = false;
  String? _imageBlocker;
  String? _paintedText;

  ui.Image? get debugImage => _image;

  String? get debugPaintedText => _paintedText;

  TextStyle? get debugPaintStyle => _paintedStyle;

  Color? get debugPaintedColor => _paintedColor;

  bool get debugImagePending => _pendingImage != null || _rasterRetry != null;

  double get debugPaintedHeight => _paintedHeight;

  double? get debugDevicePixelRatio => _imageDevicePixelRatio;

  double get debugPadding => _imagePadding;

  String? get debugImageBlocker => _imageBlocker;

  double get height => _paintedHeight;

  List<ui.LineMetrics> computeLineMetrics() {
    return _paintedLineMetrics;
  }

  static TextStyle rasterStyle(TextStyle destinationStyle) {
    return destinationStyle.copyWith(color: const Color(0xFFFFFFFF));
  }

  static String? retentionBlockerWithEndpointStyle({
    required MorphTextProperties properties,
    required double progress,
    required String? endpointStyleBlocker,
  }) {
    if (progress <= 0 || progress >= 1) return 'endpoint';
    if (properties.paintScaleX <= 0) {
      return 'horizontal scale';
    }
    if (properties.paintScaleY <= 0) {
      return 'vertical scale';
    }
    if (properties.paintScaleX == 1 && properties.paintScaleY == 1) {
      return 'unscaled';
    }
    if (properties.reservedLayoutWidth == null) return 'changing width';

    if (endpointStyleBlocker != null) return endpointStyleBlocker;
    return null;
  }

  static String? endpointStyleBlocker({
    required MorphTextProperties source,
    required MorphTextProperties destination,
  }) {
    final sourceFontSize = source.style.fontSize;
    final destinationFontSize = destination.style.fontSize;
    if (sourceFontSize == null || destinationFontSize == null || sourceFontSize == destinationFontSize) {
      return 'font size';
    }
    final sourceStyleBlocker = _unsupportedRasterStyle(source.style);
    if (sourceStyleBlocker != null) return sourceStyleBlocker;
    final destinationStyleBlocker = _unsupportedRasterStyle(
      destination.style,
    );
    if (destinationStyleBlocker != null) return destinationStyleBlocker;
    final sourceColor = source.style.color;
    final destinationColor = destination.style.color;
    if (sourceColor == null || destinationColor == null) {
      return 'solid color';
    }
    final sourceAtDestinationStyle = source.style.copyWith(
      fontSize: destinationFontSize,
      color: destinationColor,
      height: destination.style.height,
    );
    if (sourceAtDestinationStyle != destination.style) {
      return 'different endpoint style';
    }
    return null;
  }

  static double maximumScale({
    required MorphTextProperties source,
    required MorphTextProperties destination,
  }) {
    final sourceFontSize = source.style.fontSize;
    final destinationFontSize = destination.style.fontSize;
    final fontScale = sourceFontSize == null || destinationFontSize == null || destinationFontSize <= 0
        ? 1.0
        : sourceFontSize / destinationFontSize;
    final lineScale = destination.lineHeight <= 0 ? 1.0 : source.lineHeight / destination.lineHeight;
    return math.max(1, math.max(fontScale, lineScale));
  }

  bool paintRetainedImage(
    Canvas canvas, {
    required MorphTextProperties properties,
    required TextStyle rasterPaintStyle,
    required Color rasterColor,
    required double layoutWidth,
    required double devicePixelRatio,
    required double maximumScale,
    required int segment,
  }) {
    final image = _image;
    if (image == null ||
        _imageSegment != segment ||
        !_matches(
          properties,
          rasterPaintStyle,
          layoutWidth,
          devicePixelRatio,
          maximumScale,
        )) {
      return false;
    }

    try {
      _drawImage(canvas, image, rasterColor);
      _paintedText = properties.text;
      _paintedHeight = _rasterHeight;
      assert(() {
        _paintedLineMetrics = _rasterLineMetrics;
        return true;
      }(), 'Raster text line metrics should only be copied for diagnostics.');
      _paintedStyle = properties.paintStyle;
      _paintedColor = rasterColor;
      return true;
    } on Object {
      _discardImage();
      _imageDisabledForSegment = true;
      _imageBlocker = 'raster drawing failed';
      return false;
    }
  }

  void paint(
    Canvas canvas, {
    required MorphTextProperties properties,
    required TextStyle fallbackPaintStyle,
    required TextStyle rasterPaintStyle,
    required Color rasterColor,
    required double layoutWidth,
    required double devicePixelRatio,
    required int viewId,
    required double maximumScale,
    required int segment,
    required bool retainRaster,
  }) {
    _paintedText = properties.text;
    if (!retainRaster) {
      _discardImage();
      _imageBlocker = null;
      _paintFallback(
        canvas,
        properties: properties,
        paintStyle: fallbackPaintStyle,
        layoutWidth: layoutWidth,
      );
      return;
    }

    final segmentChanged = _imageSegment != segment;
    if (segmentChanged) {
      _cancelRasterRetry();
      _pendingImage = null;
      _imageSegment = segment;
      _imageDisabledForSegment = false;
      _imageBlocker = null;
    }
    final image = _image;
    if (image != null) {
      if (_matches(
        properties,
        rasterPaintStyle,
        layoutWidth,
        devicePixelRatio,
        maximumScale,
      )) {
        try {
          _drawImage(canvas, image, rasterColor);
          _paintedHeight = _rasterHeight;
          assert(() {
            _paintedLineMetrics = _rasterLineMetrics;
            return true;
          }(), 'Raster text line metrics should only be copied for diagnostics.');
          _paintedStyle = fallbackPaintStyle;
          _paintedColor = rasterColor;
          return;
        } on Object {
          _discardImage();
          _imageDisabledForSegment = true;
          _imageBlocker = 'raster drawing failed';
          _paintFallback(
            canvas,
            properties: properties,
            paintStyle: fallbackPaintStyle,
            layoutWidth: layoutWidth,
          );
          return;
        }
      }
      _discardImage();
      if (!segmentChanged) {
        _imageDisabledForSegment = true;
        _imageBlocker = 'changing paint properties';
      }
    }
    if (_imageDisabledForSegment) {
      _paintFallback(
        canvas,
        properties: properties,
        paintStyle: fallbackPaintStyle,
        layoutWidth: layoutWidth,
      );
      return;
    }

    if (_pendingImage != null || _rasterRetry != null) {
      _paintFallback(
        canvas,
        properties: properties,
        paintStyle: fallbackPaintStyle,
        layoutWidth: layoutWidth,
      );
      return;
    }

    _layout(properties, rasterPaintStyle, layoutWidth);
    _rasterHeight = _painter.height;
    assert(() {
      _rasterLineMetrics = List<ui.LineMetrics>.unmodifiable(
        _painter.computeLineMetrics(),
      );
      return true;
    }(), 'Raster text line metrics should only be retained for diagnostics.');
    final padding = _rasterPadding(rasterPaintStyle);
    final double rasterScale = math.max(1, maximumScale);
    final rasterDevicePixelRatio = devicePixelRatio * rasterScale;
    final logicalWidth = layoutWidth + padding * 2;
    final logicalHeight = _painter.height + padding * 2;
    final rasterWidth = _rasterDimension(
      logicalExtent: logicalWidth,
      devicePixelRatio: rasterDevicePixelRatio,
    );
    final rasterHeight = _rasterDimension(
      logicalExtent: logicalHeight,
      devicePixelRatio: rasterDevicePixelRatio,
    );
    final rasterBlocker = _rasterBlocker(
      devicePixelRatio: rasterDevicePixelRatio,
      width: rasterWidth,
      height: rasterHeight,
    );
    if (rasterBlocker != null) {
      _imageDisabledForSegment = true;
      _imageBlocker = rasterBlocker;
      _paintFallback(
        canvas,
        properties: properties,
        paintStyle: fallbackPaintStyle,
        layoutWidth: layoutWidth,
      );
      return;
    }

    final poolKey = _MorphTextRasterPoolKey(
      viewId: viewId,
      viewDevicePixelRatio: devicePixelRatio,
      rasterDevicePixelRatio: rasterDevicePixelRatio,
      rasterWidth: rasterWidth,
      rasterHeight: rasterHeight,
      layoutWidth: layoutWidth,
      padding: padding,
      text: properties.text,
      rasterStyle: rasterPaintStyle,
      textAlign: properties.textAlign,
      textDirection: properties.textDirection,
      locale: properties.locale,
      softWrap: properties.softWrap,
      overflow: properties.overflow,
      textScaler: properties.textScaler,
      maxLines: properties.maxLines,
      textWidthBasis: properties.textWidthBasis,
      textHeightBehavior: properties.textHeightBehavior,
      strutStyle: properties.strutStyle,
    );
    final pooledLease = rasterPool?.acquire(poolKey);
    if (pooledLease != null) {
      final pooledImage = pooledLease.image;
      _imageProperties = properties;
      _imageRasterStyle = rasterPaintStyle;
      _imageLayoutWidth = layoutWidth;
      _imageDevicePixelRatio = rasterDevicePixelRatio;
      _imageViewDevicePixelRatio = devicePixelRatio;
      _imageMaximumScale = maximumScale;
      _imagePadding = padding;
      _imageLease = pooledLease;
      _image = pooledImage;
      _drawImage(canvas, pooledImage, rasterColor);
      _paintedHeight = _rasterHeight;
      _paintedStyle = fallbackPaintStyle;
      _paintedColor = rasterColor;
      return;
    }

    if (!MorphTestConfiguration.rasterizationEnabled) {
      _imageDisabledForSegment = true;
      _imageBlocker = 'automated test configuration';
      _paintFallback(
        canvas,
        properties: properties,
        paintStyle: fallbackPaintStyle,
        layoutWidth: layoutWidth,
      );
      return;
    }

    _imageProperties = properties;
    _imageRasterStyle = rasterPaintStyle;
    _imageLayoutWidth = layoutWidth;
    _imageDevicePixelRatio = rasterDevicePixelRatio;
    _imageViewDevicePixelRatio = devicePixelRatio;
    _imageMaximumScale = maximumScale;
    _imagePadding = padding;
    Future<ui.Image> createRaster() {
      final recorder = RendererBinding.instance.createPictureRecorder();
      final recordingCanvas = RendererBinding.instance.createCanvas(recorder)
        ..scale(rasterDevicePixelRatio, rasterDevicePixelRatio)
        ..translate(padding, padding);
      _painter.paint(recordingCanvas, Offset.zero);
      final picture = recorder.endRecording();
      try {
        return picture.toImage(rasterWidth, rasterHeight).whenComplete(picture.dispose);
      } on Object {
        picture.dispose();
        rethrow;
      }
    }

    ({
      Future<_MorphTextRasterPoolLease>? lease,
      Future<bool>? retry,
      VoidCallback? cancelRetry,
    })?
    pooledLoad;
    Future<ui.Image>? localPendingImage;
    try {
      final pool = rasterPool;
      if (pool == null) {
        localPendingImage = createRaster();
      } else {
        pooledLoad = pool.load(poolKey, createRaster);
      }
    } on Object {
      _imageDisabledForSegment = true;
      _imageBlocker = 'rasterization failed';
      _paintFallback(
        canvas,
        properties: properties,
        paintStyle: fallbackPaintStyle,
        layoutWidth: layoutWidth,
      );
      return;
    }
    final retry = pooledLoad?.retry;
    if (retry != null) {
      _scheduleRasterRetry(
        retry,
        pooledLoad!.cancelRetry!,
        segment,
      );
      _paintFallback(
        canvas,
        properties: properties,
        paintStyle: fallbackPaintStyle,
        layoutWidth: layoutWidth,
      );
      return;
    }
    final pooledPendingImage = pooledLoad?.lease;
    if (pooledPendingImage == null && localPendingImage == null) {
      _imageDisabledForSegment = true;
      _imageBlocker = 'raster pool unavailable';
      _paintFallback(
        canvas,
        properties: properties,
        paintStyle: fallbackPaintStyle,
        layoutWidth: layoutWidth,
      );
      return;
    }
    late final Future<ui.Image> pendingImage;
    if (pooledPendingImage case final Future<_MorphTextRasterPoolLease> future) {
      pendingImage = future.then((lease) {
        if (!identical(_pendingImage, pendingImage)) {
          lease.release();
          throw StateError('The Morph text raster request was superseded.');
        }
        _imageLease = lease;
        return lease.image;
      });
    } else {
      pendingImage = localPendingImage!;
    }
    _pendingImage = pendingImage;
    unawaited(
      pendingImage.then(
        (raster) {
          if (!identical(_pendingImage, pendingImage)) {
            if (pooledPendingImage == null) raster.dispose();
            return;
          }
          _pendingImage = null;
          _image = raster;
          notifyListeners();
        },
        onError: (Object _) {
          if (!identical(_pendingImage, pendingImage)) return;
          _pendingImage = null;
          _imageDisabledForSegment = true;
          _imageBlocker = 'rasterization failed';
          notifyListeners();
        },
      ),
    );
    _paintFallback(
      canvas,
      properties: properties,
      paintStyle: fallbackPaintStyle,
      layoutWidth: layoutWidth,
    );
  }

  void clear() {
    _discardImage();
    _imageSegment = null;
    _imageDisabledForSegment = false;
    _imageBlocker = null;
    _paintedText = null;
    _paintedHeight = 0;
    _paintedLineMetrics = const <ui.LineMetrics>[];
    _paintedStyle = null;
    _paintedColor = null;
  }

  @override
  void dispose() {
    clear();
    _painter.dispose();
    super.dispose();
  }

  bool _matches(
    MorphTextProperties properties,
    TextStyle rasterPaintStyle,
    double layoutWidth,
    double devicePixelRatio,
    double maximumScale,
  ) {
    final cached = _imageProperties;
    return cached != null &&
        _imageLayoutWidth == layoutWidth &&
        _imageViewDevicePixelRatio == devicePixelRatio &&
        _imageMaximumScale == maximumScale &&
        cached.text == properties.text &&
        _imageRasterStyle == rasterPaintStyle &&
        cached.textAlign == properties.textAlign &&
        cached.textDirection == properties.textDirection &&
        cached.locale == properties.locale &&
        cached.softWrap == properties.softWrap &&
        cached.overflow == properties.overflow &&
        cached.textScaler == properties.textScaler &&
        cached.maxLines == properties.maxLines &&
        cached.textWidthBasis == properties.textWidthBasis &&
        cached.textHeightBehavior == properties.textHeightBehavior &&
        cached.strutStyle == properties.strutStyle;
  }

  void _layout(
    MorphTextProperties properties,
    TextStyle paintStyle,
    double layoutWidth,
  ) {
    _painter
      ..text = TextSpan(
        text: properties.text,
        style: paintStyle,
      )
      ..textAlign = properties.textAlign ?? TextAlign.start
      ..textDirection = properties.textDirection
      ..textScaler = properties.textScaler
      ..locale = properties.locale
      ..maxLines = properties.maxLines
      ..ellipsis = properties.overflow == TextOverflow.ellipsis ? '…' : null
      ..textWidthBasis = properties.textWidthBasis ?? TextWidthBasis.parent
      ..textHeightBehavior = properties.textHeightBehavior
      ..strutStyle = properties.strutStyle
      ..layout(
        minWidth: layoutWidth,
        maxWidth: (properties.softWrap ?? true) || properties.overflow == TextOverflow.ellipsis
            ? layoutWidth
            : double.infinity,
      );
  }

  void _paintFallback(
    Canvas canvas, {
    required MorphTextProperties properties,
    required TextStyle paintStyle,
    required double layoutWidth,
  }) {
    _layout(properties, paintStyle, layoutWidth);
    _paintedHeight = _painter.height;
    assert(() {
      _paintedLineMetrics = List<ui.LineMetrics>.unmodifiable(
        _painter.computeLineMetrics(),
      );
      return true;
    }(), 'Fallback line metrics should only be retained for diagnostics.');
    _paintedStyle = paintStyle;
    _paintedColor = paintStyle.color;
    _painter.paint(canvas, Offset.zero);
  }

  static String? _unsupportedRasterStyle(TextStyle style) {
    if (style.foreground != null) return 'foreground';
    if (style.background != null || style.backgroundColor != null) {
      return 'background';
    }
    if (style.shadows?.isNotEmpty ?? false) return 'shadows';
    final decoration = style.decoration;
    if (decoration != null && decoration != TextDecoration.none) {
      return 'decoration';
    }
    return null;
  }

  double _rasterPadding(TextStyle style) {
    final fontSize = style.fontSize ?? kDefaultFontSize;
    var padding = math.max<double>(2, fontSize);
    final foreground = style.foreground;
    if (foreground != null && foreground.style == PaintingStyle.stroke) {
      padding = math.max(padding, foreground.strokeWidth * 2);
    }
    final shadows = style.shadows;
    if (shadows == null) return padding;
    for (final shadow in shadows) {
      padding = math.max(
        padding,
        shadow.blurRadius * 2 + math.max(shadow.offset.dx.abs(), shadow.offset.dy.abs()),
      );
    }
    return padding;
  }

  int _rasterDimension({
    required double logicalExtent,
    required double devicePixelRatio,
  }) {
    if (!logicalExtent.isFinite || !devicePixelRatio.isFinite) return 0;
    return (logicalExtent * devicePixelRatio).ceil();
  }

  String? _rasterBlocker({
    required double devicePixelRatio,
    required int width,
    required int height,
  }) {
    if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) {
      return 'device pixel ratio';
    }
    if (width <= 0 || height <= 0) return 'empty raster';
    if (width > _maximumRasterDimension || height > _maximumRasterDimension) {
      return 'raster dimensions';
    }
    if (width * height > _maximumRasterPixels) return 'raster pixels';
    return null;
  }

  void _drawImage(Canvas canvas, ui.Image image, Color color) {
    final devicePixelRatio = _imageDevicePixelRatio!;
    final destination = Rect.fromLTWH(
      -_imagePadding,
      -_imagePadding,
      image.width / devicePixelRatio,
      image.height / devicePixelRatio,
    );
    _rasterPaint.colorFilter = ColorFilter.mode(color, BlendMode.srcIn);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      destination,
      _rasterPaint,
    );
  }

  void _scheduleRasterRetry(
    Future<bool> retry,
    VoidCallback cancelRetry,
    int segment,
  ) {
    final generation = _retryGeneration;
    _rasterRetry = retry;
    _retryCancellation = cancelRetry;
    unawaited(
      retry.then(
        (admitted) {
          if (!identical(_rasterRetry, retry) || generation != _retryGeneration || segment != _imageSegment) {
            return;
          }
          _rasterRetry = null;
          _retryCancellation = null;
          if (admitted) {
            notifyListeners();
          } else {
            _imageDisabledForSegment = true;
            _imageBlocker = 'raster scheduling invalidated';
          }
        },
        onError: (Object _) {
          if (!identical(_rasterRetry, retry) || generation != _retryGeneration || segment != _imageSegment) {
            return;
          }
          _rasterRetry = null;
          _retryCancellation = null;
          _imageDisabledForSegment = true;
          _imageBlocker = 'raster scheduling failed';
          notifyListeners();
        },
      ),
    );
  }

  void _cancelRasterRetry() {
    _retryGeneration += 1;
    _rasterRetry = null;
    final cancel = _retryCancellation;
    _retryCancellation = null;
    cancel?.call();
  }

  void _discardImage() {
    _cancelRasterRetry();
    _pendingImage = null;
    final lease = _imageLease;
    _imageLease = null;
    if (lease != null) {
      lease.release();
    } else {
      _image?.dispose();
    }
    _image = null;
    _imageProperties = null;
    _imageRasterStyle = null;
    _imageLayoutWidth = null;
    _imageDevicePixelRatio = null;
    _imageViewDevicePixelRatio = null;
    _imageMaximumScale = null;
    _imagePadding = 0;
    _rasterHeight = 0;
    _rasterLineMetrics = const <ui.LineMetrics>[];
  }
}
