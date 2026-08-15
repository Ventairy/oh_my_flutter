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
  MorphTextFlightDelegate _delegate;
  MorphFlight<MorphTextProperties> _flight;
  double _devicePixelRatio;
  int _viewId;
  _MorphFlightGeometry? _geometry;
  late TextStyle _rasterPaintStyle;
  late double _maximumScale;
  String? _endpointStyleBlocker;
  String? _rasterRetentionBlocker;
  double? _paintPropertiesProgress;
  MorphTextProperties? _paintProperties;
  int _debugLayoutCount = 0;
  int _debugPropertiesInterpolationCount = 0;

  @override
  bool get isRepaintBoundary => true;

  @override
  Rect get paintBounds => _expandedPaintBounds(
    _currentBounds,
    _propertiesAt(_flight.animation.value),
  );

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

  bool _clipsParagraph(MorphTextProperties properties) {
    return properties.overflow == TextOverflow.ellipsis ||
        (properties.overflow == TextOverflow.clip && properties.softWrap == false) ||
        properties.maxLines != null;
  }

  Rect _expandedPaintBounds(
    Rect bounds,
    MorphTextProperties properties,
  ) {
    var result = bounds;
    final foreground = properties.paintStyle.foreground;
    if (foreground != null && foreground.style == PaintingStyle.stroke) {
      result = result.inflate(foreground.strokeWidth * 2);
    }
    for (final shadow in properties.paintStyle.shadows ?? const <Shadow>[]) {
      result = result.expandToInclude(
        bounds.shift(shadow.offset).inflate(shadow.blurRadius * 2),
      );
    }
    return result.intersect(Offset.zero & size);
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
