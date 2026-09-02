part of 'morph.dart';

class _RenderMorphTextFlight extends RenderBox {
  _RenderMorphTextFlight(
    this._delegate,
    this._flight,
    this._devicePixelRatio,
    this._viewId,
    _MorphTextRasterPool? rasterPool,
    this._geometry,
  ) {
    _rasterCache.rasterPool = rasterPool;
    _updateFlightConstants();
  }

  final _MorphTextRasterCache _rasterCache = _MorphTextRasterCache();
  final _MorphTextParagraphMetricsCache _paragraphMetricsCache = _MorphTextParagraphMetricsCache();
  MorphTextFlightDelegate _delegate;
  MorphFlight<MorphTextProperties> _flight;
  double _devicePixelRatio;
  int _viewId;
  _MorphFlightGeometry? _geometry;
  late TextStyle _rasterPaintStyle;
  late double _maximumScale;
  double _maximumPaintOverflowLeft = 0;
  double _maximumPaintOverflowTop = 0;
  double _maximumPaintOverflowRight = 0;
  double _maximumPaintOverflowBottom = 0;
  String? _endpointStyleBlocker;
  String? _rasterRetentionBlocker;
  double? _paintPropertiesProgress;
  MorphTextProperties? _paintProperties;
  int _debugLayoutCount = 0;
  int _debugPropertiesInterpolationCount = 0;
  int _debugRetainedRasterFastPaintCount = 0;

  @override
  bool get isRepaintBoundary => true;

  @override
  Rect get paintBounds {
    final bounds = _currentBounds;
    return Rect.fromLTRB(
      bounds.left - _maximumPaintOverflowLeft,
      bounds.top - _maximumPaintOverflowTop,
      bounds.right + _maximumPaintOverflowRight,
      bounds.bottom + _maximumPaintOverflowBottom,
    ).intersect(Offset.zero & size);
  }

  MorphTextFlightDelegate get delegate => _delegate;

  MorphFlight<MorphTextProperties> get flight => _flight;

  double get devicePixelRatio => _devicePixelRatio;

  int get viewId => _viewId;

  _MorphTextRasterPool? get rasterPool => _rasterCache.rasterPool;

  _MorphFlightGeometry? get geometry => _geometry;

  set geometry(_MorphFlightGeometry? value) {
    if (identical(value, _geometry)) return;
    if (attached) _geometry?.removeListener(markNeedsPaint);
    _geometry = value;
    if (attached) _geometry?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  set delegate(MorphTextFlightDelegate value) {
    if (identical(value, _delegate)) return;
    _delegate = value;
    _clearPaintProperties();
    _paragraphMetricsCache.clear();
    _rasterCache.clear();
    markNeedsPaint();
  }

  set flight(MorphFlight<MorphTextProperties> value) {
    if (identical(value, _flight)) return;
    if (attached) {
      _flight.animation.removeListener(markNeedsPaint);
    }
    _flight = value;
    _clearPaintProperties();
    _paragraphMetricsCache.clear();
    _rasterCache.clear();
    _updateFlightConstants();
    if (attached) _flight.animation.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    _rasterCache.clear();
    markNeedsPaint();
  }

  set viewId(int value) {
    if (value == _viewId) return;
    _viewId = value;
    _rasterCache.clear();
    markNeedsPaint();
  }

  set rasterPool(_MorphTextRasterPool? value) {
    if (identical(value, _rasterCache.rasterPool)) return;
    _rasterCache
      ..clear()
      ..rasterPool = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _flight.animation.addListener(markNeedsPaint);
    _rasterCache.addListener(markNeedsPaint);
    _geometry?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _flight.animation.removeListener(markNeedsPaint);
    _rasterCache.removeListener(markNeedsPaint);
    _geometry?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _rasterCache.dispose();
    super.dispose();
  }

  @override
  void performLayout() {
    assert(() {
      _debugLayoutCount += 1;
      return true;
    }(), 'Retained Text flight layout should be observable in debug mode.');
    size = constraints.biggest.isFinite ? constraints.biggest : constraints.constrain(Size.zero);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final progress = _flight.animation.value;
    final bounds = _currentBounds;
    if (bounds.isEmpty) return;
    if (_paintRetainedRaster(
      context.canvas,
      offset: offset,
      bounds: bounds,
      progress: progress,
    )) {
      return;
    }
    final properties = _propertiesAt(progress);
    final layoutWidth = _delegate._paintLayoutWidth(
      properties: properties,
      availableWidth: bounds.width,
    );
    final textLayoutWidth = layoutWidth ?? bounds.width;
    final source = _flight._sourceProperties;
    _rasterRetentionBlocker = _MorphTextRasterCache.retentionBlockerWithEndpointStyle(
      properties: properties,
      progress: progress,
      endpointStyleBlocker: _endpointStyleBlocker,
    );

    context.canvas.save();
    if (_clipsParagraph(properties)) {
      context.canvas.clipRect(bounds.shift(offset));
    }
    final isLeftToRight = properties.textDirection == TextDirection.ltr;
    context.canvas
      ..translate(
        offset.dx + (isLeftToRight ? bounds.left : bounds.right),
        offset.dy + bounds.top + properties.baselineOffset,
      )
      ..scale(properties.paintScaleX, properties.paintScaleY);
    if (!isLeftToRight) {
      context.canvas.translate(-textLayoutWidth, 0);
    }
    _rasterCache.paint(
      context.canvas,
      properties: properties,
      fallbackPaintStyle: properties.paintStyle,
      rasterPaintStyle: _rasterPaintStyle,
      rasterColor: properties.paintStyle.color ?? const Color(0x00000000),
      layoutWidth: textLayoutWidth,
      devicePixelRatio: _devicePixelRatio,
      viewId: _viewId,
      maximumScale: _maximumScale,
      segment: progress < source.switchThreshold ? 0 : 1,
      retainRaster: _rasterRetentionBlocker == null,
    );
    context.canvas.restore();
  }

  bool _paintRetainedRaster(
    Canvas canvas, {
    required Offset offset,
    required Rect bounds,
    required double progress,
  }) {
    if (_endpointStyleBlocker != null || progress <= 0 || progress >= 1) {
      return false;
    }

    final source = _flight._sourceProperties;
    final destination = _flight._destinationProperties;
    if (source.strutStyle != null || destination.strutStyle != null) {
      return false;
    }
    final sourceFontSize = source.style.fontSize;
    final destinationFontSize = destination.style.fontSize;
    final sourceColor = source.style.color;
    final destinationColor = destination.style.color;
    if (sourceFontSize == null ||
        sourceFontSize <= 0 ||
        destinationFontSize == null ||
        destinationFontSize <= 0 ||
        destination.lineHeight <= 0 ||
        sourceColor == null ||
        destinationColor == null) {
      return false;
    }

    final showSource = progress < source.switchThreshold;
    final selected = showSource ? source : destination;
    final layoutWidth = _delegate._reservedLayoutWidth(
      source: source,
      destination: destination,
      showSource: showSource,
    );
    if (layoutWidth == null) return false;

    final endpointScaleX = _delegate._lerpDouble(
      source.endpointScaleX,
      destination.endpointScaleX,
      progress,
    );
    final endpointScaleY = _delegate._lerpDouble(
      source.endpointScaleY,
      destination.endpointScaleY,
      progress,
    );
    if (endpointScaleY <= 0) return false;
    final interpolatedFontSize = _delegate._lerpDouble(
      sourceFontSize,
      destinationFontSize,
      progress,
    );
    final paintScaleX = endpointScaleX / endpointScaleY * interpolatedFontSize / destinationFontSize;
    final lineHeight = _delegate._lerpDouble(
      source.lineHeight,
      destination.lineHeight,
      progress,
    );
    final paintScaleY = lineHeight / destination.lineHeight;
    if (paintScaleX <= 0 || paintScaleY <= 0 || (paintScaleX == 1 && paintScaleY == 1)) {
      return false;
    }
    final baseline = _delegate._lerpDouble(
      source.baseline,
      destination.baseline,
      progress,
    );
    final baselineOffset = baseline - destination.baseline * paintScaleY;
    final rasterColor = Color.lerp(
      sourceColor,
      destinationColor,
      progress,
    )!;
    final segment = showSource ? 0 : 1;

    canvas.save();
    if (_clipsParagraph(selected)) {
      canvas.clipRect(bounds.shift(offset));
    }
    final isLeftToRight = selected.textDirection == TextDirection.ltr;
    canvas
      ..translate(
        offset.dx + (isLeftToRight ? bounds.left : bounds.right),
        offset.dy + bounds.top + baselineOffset,
      )
      ..scale(paintScaleX, paintScaleY);
    if (!isLeftToRight) {
      canvas.translate(-layoutWidth, 0);
    }
    final painted = _rasterCache.paintRetainedImage(
      canvas,
      properties: selected,
      rasterPaintStyle: _rasterPaintStyle,
      rasterColor: rasterColor,
      layoutWidth: layoutWidth,
      devicePixelRatio: _devicePixelRatio,
      maximumScale: _maximumScale,
      segment: segment,
    );
    canvas.restore();
    if (!painted) return false;

    _rasterRetentionBlocker = null;
    assert(() {
      _debugRetainedRasterFastPaintCount += 1;
      return true;
    }(), 'Retained raster fast paints should be observable in debug mode.');
    return true;
  }

  bool _clipsParagraph(MorphTextProperties properties) {
    return properties.overflow == TextOverflow.ellipsis ||
        (properties.overflow == TextOverflow.clip && properties.softWrap == false) ||
        properties.maxLines != null;
  }

  void _includePaintOverflow(TextStyle style) {
    final foreground = style.foreground;
    if (foreground != null && foreground.style == PaintingStyle.stroke) {
      final overflow = foreground.strokeWidth * 2;
      _maximumPaintOverflowLeft = math.max(
        _maximumPaintOverflowLeft,
        overflow,
      );
      _maximumPaintOverflowTop = math.max(
        _maximumPaintOverflowTop,
        overflow,
      );
      _maximumPaintOverflowRight = math.max(
        _maximumPaintOverflowRight,
        overflow,
      );
      _maximumPaintOverflowBottom = math.max(
        _maximumPaintOverflowBottom,
        overflow,
      );
    }
    for (final shadow in style.shadows ?? const <Shadow>[]) {
      final blurOverflow = shadow.blurRadius * 2;
      _maximumPaintOverflowLeft = math.max(
        _maximumPaintOverflowLeft,
        math.max(0, blurOverflow - shadow.offset.dx),
      );
      _maximumPaintOverflowTop = math.max(
        _maximumPaintOverflowTop,
        math.max(0, blurOverflow - shadow.offset.dy),
      );
      _maximumPaintOverflowRight = math.max(
        _maximumPaintOverflowRight,
        math.max(0, blurOverflow + shadow.offset.dx),
      );
      _maximumPaintOverflowBottom = math.max(
        _maximumPaintOverflowBottom,
        math.max(0, blurOverflow + shadow.offset.dy),
      );
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    _debugFillRasterPoolProperties(properties);
    _debugFillPaintedTextProperties(properties);
    _debugFillFlightProperties(properties);
  }

  void _debugFillRasterPoolProperties(
    DiagnosticPropertiesBuilder properties,
  ) {
    properties
      ..add(
        IntProperty(
          'retainedTextRasterPoolEntries',
          _rasterCache.rasterPool?.debugEntryCount,
        ),
      )
      ..add(
        IntProperty(
          'retainedTextRasterPoolRegistryEntries',
          _rasterCache.rasterPool?.debugRegisteredPoolCount,
        ),
      )
      ..add(
        IntProperty(
          'retainedTextRasterPoolPixels',
          _rasterCache.rasterPool?.debugPixelCount,
        ),
      )
      ..add(
        IntProperty(
          'retainedTextRasterPoolOwnedEntries',
          _rasterCache.rasterPool?.debugOwnedEntryCount,
        ),
      )
      ..add(
        IntProperty(
          'retainedTextRasterPoolOwnedPixels',
          _rasterCache.rasterPool?.debugOwnedPixelCount,
        ),
      )
      ..add(
        IntProperty(
          'retainedTextRasterPoolReservedEntries',
          _rasterCache.rasterPool?.debugReservedEntryCount,
        ),
      )
      ..add(
        IntProperty(
          'retainedTextRasterPoolReservedPixels',
          _rasterCache.rasterPool?.debugReservedPixelCount,
        ),
      )
      ..add(
        IntProperty(
          'retainedTextRasterPoolBudgetedEntries',
          _rasterCache.rasterPool?.debugBudgetedEntryCount,
        ),
      )
      ..add(
        IntProperty(
          'retainedTextRasterPoolBudgetedPixels',
          _rasterCache.rasterPool?.debugBudgetedPixelCount,
        ),
      )
      ..add(
        FlagProperty(
          'retainedTextRasterPoolFinalizerAttached',
          value: _rasterCache.rasterPool?.debugFinalizerAttached,
          ifTrue: 'attached',
        ),
      )
      ..add(
        IntProperty(
          'retainedTextRasterPoolHits',
          _rasterCache.rasterPool?.debugHitCount,
        ),
      )
      ..add(
        IntProperty(
          'retainedTextRasterPoolMisses',
          _rasterCache.rasterPool?.debugMissCount,
        ),
      )
      ..add(
        IntProperty(
          'retainedTextRasterPoolCreates',
          _rasterCache.rasterPool?.debugCreateCount,
        ),
      )
      ..add(
        IntProperty(
          'retainedTextRasterPoolDeferred',
          _rasterCache.rasterPool?.debugDeferredCount,
        ),
      )
      ..add(
        FlagProperty(
          'retainedTextRasterPoolFrameScheduled',
          value: _rasterCache.rasterPool?.debugHasScheduledFrame,
          ifTrue: 'scheduled',
        ),
      )
      ..add(
        IntProperty(
          'retainedTextRasterPoolStarts',
          _rasterCache.rasterPool?.debugStartCount,
        ),
      )
      ..add(
        IntProperty(
          'retainedTextRasterPoolLateDisposals',
          _rasterCache.rasterPool?.debugLateDisposalCount,
        ),
      );
  }

  void _debugFillPaintedTextProperties(
    DiagnosticPropertiesBuilder properties,
  ) {
    properties
      ..add(
        DiagnosticsProperty<ui.Image>(
          'retainedTextRaster',
          _rasterCache.debugImage,
        ),
      )
      ..add(
        StringProperty(
          'paintedText',
          _rasterCache.debugPaintedText,
        ),
      )
      ..add(
        ColorProperty(
          'paintedColor',
          _rasterCache.debugPaintedColor,
        ),
      )
      ..add(
        FlagProperty(
          'retainedTextRasterPending',
          value: _rasterCache.debugImagePending,
          ifTrue: 'pending',
        ),
      )
      ..add(
        DoubleProperty(
          'paintedTextHeight',
          _rasterCache.debugPaintedHeight,
        ),
      )
      ..add(
        IntProperty(
          'paintedLineCount',
          _rasterCache.computeLineMetrics().length,
        ),
      )
      ..add(
        IntProperty(
          'retainedRasterFastPaintCount',
          _debugRetainedRasterFastPaintCount,
        ),
      )
      ..add(
        DoubleProperty(
          'interpolatedTextLayoutWidth',
          _propertiesAt(_flight.animation.value).layoutWidth,
        ),
      )
      ..add(
        StringProperty(
          'rasterRetentionBlocker',
          _rasterRetentionBlocker ?? _rasterCache.debugImageBlocker,
        ),
      )
      ..add(
        DoubleProperty(
          'retainedTextRasterDevicePixelRatio',
          _rasterCache.debugDevicePixelRatio,
        ),
      )
      ..add(
        DoubleProperty(
          'retainedTextRasterPadding',
          _rasterCache.debugPadding,
        ),
      );
  }

  void _debugFillFlightProperties(
    DiagnosticPropertiesBuilder properties,
  ) {
    properties
      ..add(
        DiagnosticsProperty<Rect>(
          'paintBounds',
          paintBounds,
        ),
      )
      ..add(
        IntProperty(
          'layoutCount',
          _debugLayoutCount,
        ),
      )
      ..add(
        IntProperty(
          'propertiesInterpolationCount',
          _debugPropertiesInterpolationCount,
        ),
      );
  }

  Rect get _currentBounds {
    return Rect.lerp(
      _geometry?.sourceBounds ?? _flight._sourceSnapshot.bounds,
      _geometry?.destinationBounds ?? _flight._destinationSnapshot.bounds,
      _flight.animation.value,
    )!;
  }

  void _updateFlightConstants() {
    final source = _flight._sourceProperties;
    final destination = _flight._destinationProperties;
    _maximumPaintOverflowLeft = 0;
    _maximumPaintOverflowTop = 0;
    _maximumPaintOverflowRight = 0;
    _maximumPaintOverflowBottom = 0;
    _includePaintOverflow(source.paintStyle);
    _includePaintOverflow(destination.paintStyle);
    _rasterPaintStyle = _MorphTextRasterCache.rasterStyle(
      destination.style,
    );
    _maximumScale = _MorphTextRasterCache.maximumScale(
      source: source,
      destination: destination,
    );
    _endpointStyleBlocker = _MorphTextRasterCache.endpointStyleBlocker(
      source: source,
      destination: destination,
    );
  }

  MorphTextProperties _propertiesAt(double progress) {
    final cached = _paintProperties;
    if (cached != null && _paintPropertiesProgress == progress) return cached;

    final properties = _delegate._lerpForPaint(
      _flight._sourceProperties,
      _flight._destinationProperties,
      progress,
      _paragraphMetricsCache,
    );
    _paintPropertiesProgress = progress;
    _paintProperties = properties;
    assert(() {
      _debugPropertiesInterpolationCount += 1;
      return true;
    }(), 'Text property interpolation should be observable in debug mode.');
    return properties;
  }

  void _clearPaintProperties() {
    _paintPropertiesProgress = null;
    _paintProperties = null;
  }
}
