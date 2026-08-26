part of 'morph.dart';

class _MorphCompoundFlightPlan extends ChangeNotifier {
  _MorphCompoundFlightPlan._({
    required this.textDirection,
    required this.sourceChild,
    required this.destinationChild,
    required this.sourceContainer,
    required this.destinationContainer,
    required this.sourceColumn,
    required this.destinationColumn,
    required this.children,
    required this.switchThreshold,
    required this.departureThresholdIsInclusive,
    required this.isRoot,
  }) : _textRasterStyle = _createTextRasterStyle(
         sourceChild,
         destinationChild,
       ),
       _textIsStatic = _haveEqualTextProperties(
         sourceChild,
         destinationChild,
       ),
       _rectIsStatic = _haveEqualRects(
         sourceChild,
         destinationChild,
       ),
       _paddingIsStatic = _haveEqualPadding(
         sourceChild,
         destinationChild,
       ),
       _backgroundDecorationIsStatic = _haveEqualBoxDecorations(
         sourceContainer?.decoration,
         destinationContainer?.decoration,
       ),
       _foregroundDecorationIsStatic = _haveEqualBoxDecorations(
         sourceContainer?.foregroundDecoration,
         destinationContainer?.foregroundDecoration,
       ),
       _textEndpointStyleBlocker = _createTextEndpointStyleBlocker(
         sourceChild,
         destinationChild,
       ),
       _textMaximumScale = _createTextMaximumScale(
         sourceChild,
         destinationChild,
       ) {
    for (final child in children) {
      child.addListener(notifyListeners);
    }
  }

  static _MorphCompoundFlightPlan? forContainer({
    required MorphContainerProperties source,
    required MorphContainerProperties destination,
    required TextDirection textDirection,
  }) {
    if (!_supportsContainer(source) || !_supportsContainer(destination)) {
      return null;
    }
    final children = _containerChildren(
      source: source,
      destination: destination,
      textDirection: textDirection,
    );
    if (children == null) return null;

    return _MorphCompoundFlightPlan._(
      textDirection: textDirection,
      sourceChild: null,
      destinationChild: null,
      sourceContainer: source,
      destinationContainer: destination,
      sourceColumn: null,
      destinationColumn: null,
      children: children,
      switchThreshold: source.switchThreshold,
      departureThresholdIsInclusive: false,
      isRoot: true,
    );
  }

  static _MorphCompoundFlightPlan? forColumn({
    required MorphColumnProperties source,
    required MorphColumnProperties destination,
    required TextDirection textDirection,
  }) {
    final children = _columnChildren(
      source: source,
      destination: destination,
      textDirection: textDirection,
    );
    if (children == null) return null;

    return _MorphCompoundFlightPlan._(
      textDirection: textDirection,
      sourceChild: null,
      destinationChild: null,
      sourceContainer: null,
      destinationContainer: null,
      sourceColumn: source,
      destinationColumn: destination,
      children: children,
      switchThreshold: source.switchThreshold,
      departureThresholdIsInclusive: true,
      isRoot: true,
    );
  }

  final TextDirection textDirection;
  final MorphChildProperties? sourceChild;
  final MorphChildProperties? destinationChild;
  final MorphContainerProperties? sourceContainer;
  final MorphContainerProperties? destinationContainer;
  final MorphColumnProperties? sourceColumn;
  final MorphColumnProperties? destinationColumn;
  final List<_MorphCompoundFlightPlan> children;
  final double switchThreshold;
  final bool departureThresholdIsInclusive;
  final bool isRoot;
  final TextStyle? _textRasterStyle;
  final bool _textIsStatic;
  final bool _rectIsStatic;
  final bool _paddingIsStatic;
  final bool _backgroundDecorationIsStatic;
  final bool _foregroundDecorationIsStatic;
  final String? _textEndpointStyleBlocker;
  final double _textMaximumScale;

  _MorphTextRasterCache? _textRasterCache;
  double? _devicePixelRatio;
  int? _viewId;
  _MorphTextRasterPool? _rasterPool;
  Paint? _backgroundPaint;
  Paint? _foregroundPaint;
  Paint? _saveLayerPaint;
  double? _cachedTextProgress;
  MorphTextProperties? _cachedTextProperties;
  bool _hasCachedTextProperties = false;
  double? _cachedDecorationProgress;
  BoxDecoration? _cachedBackgroundDecoration;
  BoxDecoration? _cachedForegroundDecoration;
  bool _hasCachedDecorations = false;
  double? _debugTextInterpolationProgress;
  int _debugTextInterpolationsAtProgress = 0;
  double? _debugDecorationInterpolationProgress;
  int _debugDecorationInterpolationsAtProgress = 0;
  final List<Map<String, Object?>> _debugTextLayouts = <Map<String, Object?>>[];

  List<Map<String, Object?>> get debugTextLayouts {
    final layouts = <Map<String, Object?>>[..._debugTextLayouts];
    for (final child in children) {
      layouts.addAll(child.debugTextLayouts);
    }
    return layouts;
  }

  _MorphTextRasterPool? get rasterPool => _rasterPool;

  int? get viewId => _viewId;

  int get debugDecorationInterpolationsAtProgress {
    return _debugDecorationInterpolationsAtProgress;
  }

  set rasterPool(_MorphTextRasterPool? value) {
    if (identical(value, _rasterPool)) return;
    _rasterPool = value;
    _textRasterCache?.rasterPool = value;
    for (final child in children) {
      child.rasterPool = value;
    }
  }

  set viewId(int value) {
    if (value == _viewId) return;
    _viewId = value;
    _textRasterCache?.clear();
    for (final child in children) {
      child.viewId = value;
    }
  }

  void paint(
    Canvas canvas,
    Rect bounds,
    double progress, {
    required double devicePixelRatio,
  }) {
    _updateDevicePixelRatio(devicePixelRatio);
    assert(() {
      _clearDebugTextLayouts();
      return true;
    }(), 'Retained-flight debug layouts should reset before painting.');
    final sourceContainer = this.sourceContainer;
    final destinationContainer = this.destinationContainer;
    if (sourceContainer != null && destinationContainer != null) {
      _paintContainer(
        canvas,
        bounds,
        sourceContainer,
        destinationContainer,
        progress,
      );
      return;
    }

    final sourceColumn = this.sourceColumn;
    final destinationColumn = this.destinationColumn;
    if (sourceColumn != null && destinationColumn != null) {
      _paintColumn(canvas, bounds, progress);
    }
  }

  Rect paintBounds(Rect bounds, double progress) {
    var result = bounds;
    final background = _backgroundDecorationAt(progress);
    final foreground = _foregroundDecorationAt(progress);
    result = _expandForDecorationShadows(result, bounds, background);
    result = _expandForDecorationShadows(result, bounds, foreground);

    if (sourceContainer != null || destinationContainer != null) {
      if (children.isEmpty) return result;
      final child = children.single;
      if (!child._isVisible(progress)) return result;
      final childRect = child._rectAt(progress).shift(bounds.topLeft);
      return result.expandToInclude(
        child._childPaintBounds(
          childRect,
          progress,
          owningBounds: bounds,
        ),
      );
    }

    if (sourceColumn != null || destinationColumn != null) {
      _MorphCompoundFlightPlan? previousChild;
      var previousPaintBottom = 0.0;
      for (final child in children) {
        if (!child._isVisible(progress)) continue;
        final layoutRect = child._rectAt(progress);
        final previous = previousChild;
        final top = previous == null ? layoutRect.top : previousPaintBottom + child._columnGapAfter(previous, progress);
        final childRect = Rect.fromLTWH(
          bounds.left + layoutRect.left,
          bounds.top + top,
          layoutRect.width,
          layoutRect.height,
        );
        result = result.expandToInclude(
          child._childPaintBounds(
            childRect,
            progress,
            owningBounds: bounds,
          ),
        );
        previousChild = child;
        previousPaintBottom =
            top +
            child._estimatedPaintHeight(
              childRect,
              progress,
            );
      }
    }
    return result;
  }

  Rect _expandForDecorationShadows(
    Rect result,
    Rect bounds,
    BoxDecoration? decoration,
  ) {
    final shadows = decoration?.boxShadow;
    if (shadows == null) return result;
    var expanded = result;
    for (final shadow in shadows) {
      final shadowBounds = bounds
          .shift(shadow.offset)
          .inflate(
            shadow.spreadRadius + shadow.blurRadius * 2,
          );
      expanded = expanded.expandToInclude(shadowBounds);
    }
    return expanded;
  }

  Rect _childPaintBounds(
    Rect rect,
    double progress, {
    required Rect owningBounds,
  }) {
    final padding = _paddingAt(progress);
    final innerRect = Rect.fromLTRB(
      math.min(rect.right, rect.left + padding.left),
      math.min(rect.bottom, rect.top + padding.top),
      math.max(rect.left, rect.right - padding.right),
      math.max(rect.top, rect.bottom - padding.bottom),
    );
    final text = _textAt(progress);
    if (text != null) {
      final textBounds = _resolvedTextPaintBounds(innerRect, text);
      final style = text.paintStyle;
      var overflow = style.fontSize ?? kDefaultFontSize;
      final foreground = style.foreground;
      if (foreground != null && foreground.style == PaintingStyle.stroke) {
        overflow = math.max(overflow, foreground.strokeWidth * 2);
      }
      for (final shadow in style.shadows ?? const <Shadow>[]) {
        overflow = math.max(
          overflow,
          shadow.blurRadius * 2 + math.max(shadow.offset.dx.abs(), shadow.offset.dy.abs()),
        );
      }
      final expandedBounds = textBounds.inflate(overflow);
      return _shouldClipText(text, innerRect) ? expandedBounds.intersect(owningBounds) : expandedBounds;
    }
    return paintBounds(innerRect, progress);
  }

  double _estimatedPaintHeight(Rect rect, double progress) {
    final text = _textAt(progress);
    if (text == null) return rect.height;
    final padding = _paddingAt(progress);
    final innerHeight = rect.height - math.min(rect.height, padding.vertical);
    return _resolvedTextPaintHeight(innerHeight, text) + padding.vertical;
  }

  bool get _hasCapturedSize => sourceChild?.explicitSize != null || destinationChild?.explicitSize != null;

  double _resolvedTextPaintHeight(
    double capturedHeight,
    MorphTextProperties properties,
  ) {
    if (_hasCapturedSize) return capturedHeight;
    return math.max(0, properties.baselineOffset + properties.estimatedHeight);
  }

  Rect _resolvedTextPaintBounds(
    Rect bounds,
    MorphTextProperties properties,
  ) {
    if (_hasCapturedSize) return bounds;
    final paragraph = Rect.fromLTWH(
      bounds.left,
      bounds.top + properties.baselineOffset,
      bounds.width,
      properties.estimatedHeight,
    );
    return bounds.expandToInclude(paragraph);
  }

  bool _shouldClipText(
    MorphTextProperties properties,
    Rect bounds,
  ) {
    final exceedsCapturedHeight = properties.baselineOffset + properties.estimatedHeight > bounds.height;
    return properties.overflow == TextOverflow.ellipsis ||
        (properties.overflow == TextOverflow.clip && properties.softWrap == false) ||
        properties.maxLines != null ||
        (properties.overflow != TextOverflow.visible && exceedsCapturedHeight);
  }

  MorphTextProperties? _textAt(double progress) {
    if (_hasCachedTextProperties && _cachedTextProgress == progress) {
      return _cachedTextProperties;
    }
    final source = sourceChild?.text;
    final destination = destinationChild?.text;
    final properties = switch ((source, destination)) {
      (final MorphTextProperties source, final MorphTextProperties _) when _textIsStatic => source,
      (final MorphTextProperties source, final MorphTextProperties destination) => _interpolateText(
        source,
        destination,
        progress,
      ),
      (final MorphTextProperties source, null) => source,
      (null, final MorphTextProperties destination) => destination,
      _ => null,
    };
    _cachedTextProgress = progress;
    _cachedTextProperties = properties;
    _hasCachedTextProperties = true;
    return properties;
  }

  MorphTextProperties _interpolateText(
    MorphTextProperties source,
    MorphTextProperties destination,
    double progress,
  ) {
    assert(
      _recordTextInterpolation(progress),
      'Retained Text interpolation should be observable in diagnostics.',
    );
    return const MorphTextFlightDelegate()._lerpForPaint(
      source,
      destination,
      progress,
    );
  }

  bool _recordTextInterpolation(double progress) {
    if (_debugTextInterpolationProgress == progress) {
      _debugTextInterpolationsAtProgress += 1;
    } else {
      _debugTextInterpolationProgress = progress;
      _debugTextInterpolationsAtProgress = 1;
    }
    return true;
  }

  BoxDecoration? _backgroundDecorationAt(double progress) {
    _updateDecorations(progress);
    return _cachedBackgroundDecoration;
  }

  BoxDecoration? _foregroundDecorationAt(double progress) {
    _updateDecorations(progress);
    return _cachedForegroundDecoration;
  }

  void _updateDecorations(double progress) {
    if (_hasCachedDecorations && _cachedDecorationProgress == progress) {
      return;
    }
    _cachedBackgroundDecoration = _decorationAt(
      sourceContainer?.decoration,
      destinationContainer?.decoration,
      progress,
      isStatic: _backgroundDecorationIsStatic,
    );
    _cachedForegroundDecoration = _decorationAt(
      sourceContainer?.foregroundDecoration,
      destinationContainer?.foregroundDecoration,
      progress,
      isStatic: _foregroundDecorationIsStatic,
    );
    _cachedDecorationProgress = progress;
    _hasCachedDecorations = true;
  }

  BoxDecoration? _decorationAt(
    Decoration? source,
    Decoration? destination,
    double progress, {
    required bool isStatic,
  }) {
    return switch ((source, destination)) {
      (final BoxDecoration source, final BoxDecoration _) when isStatic => source,
      (final BoxDecoration source, final BoxDecoration destination) => _interpolateDecoration(
        source,
        destination,
        progress,
      ),
      (final BoxDecoration source, null) => source,
      (null, final BoxDecoration destination) => destination,
      _ => null,
    };
  }

  BoxDecoration? _interpolateDecoration(
    BoxDecoration source,
    BoxDecoration destination,
    double progress,
  ) {
    assert(
      _recordDecorationInterpolation(progress),
      'Retained decoration interpolation should be observable in diagnostics.',
    );
    return BoxDecoration.lerp(source, destination, progress);
  }

  bool _recordDecorationInterpolation(double progress) {
    if (_debugDecorationInterpolationProgress == progress) {
      _debugDecorationInterpolationsAtProgress += 1;
    } else {
      _debugDecorationInterpolationProgress = progress;
      _debugDecorationInterpolationsAtProgress = 1;
    }
    return true;
  }

  @override
  void dispose() {
    _textRasterCache?.dispose();
    for (final child in children) {
      child
        ..removeListener(notifyListeners)
        ..dispose();
    }
    super.dispose();
  }

  double _paintChild(
    Canvas canvas,
    Rect rect,
    double progress, {
    required Rect owningBounds,
  }) {
    final padding = _paddingAt(progress);
    final innerRect = Rect.fromLTRB(
      math.min(rect.right, rect.left + padding.left),
      math.min(rect.bottom, rect.top + padding.top),
      math.max(rect.left, rect.right - padding.right),
      math.max(rect.top, rect.bottom - padding.bottom),
    );
    final sourceText = sourceChild?.text;
    final destinationText = destinationChild?.text;
    final hasInterpolatedText = sourceText != null && destinationText != null;
    if (sourceText != null || destinationText != null) {
      final textHeight = _paintText(
        canvas,
        innerRect,
        sourceText,
        destinationText,
        progress,
        owningBounds: owningBounds,
      );
      return hasInterpolatedText ? textHeight + padding.vertical : rect.height;
    }

    final sourceContainer = this.sourceContainer;
    final destinationContainer = this.destinationContainer;
    if (sourceContainer != null || destinationContainer != null) {
      _paintSelectedOrInterpolatedContainer(
        canvas,
        innerRect,
        sourceContainer,
        destinationContainer,
        progress,
      );
    } else if (sourceColumn != null || destinationColumn != null) {
      _paintSelectedOrInterpolatedColumn(canvas, innerRect, progress);
    }
    return rect.height;
  }

  double _paintText(
    Canvas canvas,
    Rect bounds,
    MorphTextProperties? source,
    MorphTextProperties? destination,
    double progress, {
    required Rect owningBounds,
  }) {
    final properties = _textAt(progress) ?? (throw StateError('A retained text child has no endpoint.'));
    final layoutWidth = const MorphTextFlightDelegate()._paintLayoutWidth(
      properties: properties,
      availableWidth: bounds.width,
    );
    final double textLayoutWidth = math.max(0, layoutWidth ?? bounds.width);
    final rasterCache = _textRasterCache ??= _MorphTextRasterCache()
      ..rasterPool = _rasterPool
      ..addListener(notifyListeners);

    final isLeftToRight = properties.textDirection == TextDirection.ltr;
    final rasterRetentionBlocker = source == null || destination == null
        ? 'unmatched endpoint'
        : _MorphTextRasterCache.retentionBlockerWithEndpointStyle(
            properties: properties,
            progress: progress,
            endpointStyleBlocker: _textEndpointStyleBlocker,
          );
    final resolvedBounds = _resolvedTextPaintBounds(bounds, properties);
    final clipBounds = resolvedBounds.intersect(owningBounds);
    final shouldClip = _shouldClipText(properties, bounds);
    canvas.save();
    if (shouldClip) {
      canvas.clipRect(clipBounds);
    }
    canvas
      ..translate(
        bounds.left + (isLeftToRight ? 0 : bounds.width),
        bounds.top + properties.baselineOffset,
      )
      ..scale(properties.paintScaleX, properties.paintScaleY);
    if (!isLeftToRight) canvas.translate(-textLayoutWidth, 0);
    rasterCache.paint(
      canvas,
      properties: properties,
      fallbackPaintStyle: properties.paintStyle,
      rasterPaintStyle: _textRasterStyle!,
      rasterColor: properties.paintStyle.color ?? const Color(0x00000000),
      layoutWidth: textLayoutWidth,
      devicePixelRatio: _devicePixelRatio!,
      viewId: _viewId ?? 0,
      maximumScale: _textMaximumScale,
      segment: progress < (source ?? destination!).switchThreshold ? 0 : 1,
      retainRaster: rasterRetentionBlocker == null,
    );
    canvas.restore();
    final paintedHeight = rasterCache.height * properties.paintScaleY;
    assert(
      (paintedHeight - properties.estimatedHeight).abs() <= precisionErrorTolerance,
      'Retained-flight text height should match its resolved paragraph height. '
      'resolved=${properties.estimatedHeight}, painted=$paintedHeight',
    );
    assert(() {
      final lineMetrics = rasterCache.computeLineMetrics();
      _debugTextLayouts.add(<String, Object?>{
        'text': properties.text,
        'rect': Rect.fromLTWH(
          bounds.left,
          bounds.top + properties.baselineOffset,
          bounds.width,
          properties.estimatedHeight,
        ),
        'style': rasterCache.debugPaintStyle ?? properties.paintStyle,
        'textDirection': properties.textDirection,
        'textScaler': properties.textScaler,
        'maxLines': properties.maxLines,
        'overflow': properties.overflow,
        'clipRect': shouldClip ? clipBounds : resolvedBounds,
        'paintScaleX': properties.paintScaleX,
        'paintScaleY': properties.paintScaleY,
        'baseline':
            bounds.top + properties.baselineOffset + (lineMetrics.firstOrNull?.baseline ?? 0) * properties.paintScaleY,
        'paintedLineCount': lineMetrics.length,
        'raster': rasterCache.debugImage,
        'rasterDevicePixelRatio': rasterCache.debugDevicePixelRatio,
        'rasterPadding': rasterCache.debugPadding,
        'rasterRetentionBlocker': rasterRetentionBlocker ?? rasterCache.debugImageBlocker,
        'interpolationsAtProgress': _debugTextInterpolationsAtProgress,
        'rectIsStatic': _rectIsStatic,
        'paddingIsStatic': _paddingIsStatic,
      });
      return true;
    }(), 'Retained-flight text diagnostics should describe the current paint.');
    return _resolvedTextPaintHeight(bounds.height, properties);
  }

  void _updateDevicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    _textRasterCache?.clear();
    for (final child in children) {
      child._updateDevicePixelRatio(value);
    }
  }

  void _clearDebugTextLayouts() {
    _debugTextLayouts.clear();
    for (final child in children) {
      child._clearDebugTextLayouts();
    }
  }

  void _paintSelectedOrInterpolatedContainer(
    Canvas canvas,
    Rect bounds,
    MorphContainerProperties? source,
    MorphContainerProperties? destination,
    double progress,
  ) {
    if (source != null && destination != null) {
      _paintContainer(canvas, bounds, source, destination, progress);
      return;
    }
    if (source != null) {
      _paintContainer(canvas, bounds, source, source, 0);
      return;
    }
    if (destination != null) {
      _paintContainer(canvas, bounds, destination, destination, 1);
    }
  }

  void _paintContainer(
    Canvas canvas,
    Rect bounds,
    MorphContainerProperties source,
    MorphContainerProperties destination,
    double progress,
  ) {
    final background = _backgroundDecorationAt(progress);
    _paintContainerBackground(canvas, bounds, progress);

    final clipBehavior = progress < source.switchThreshold ? source.clipBehavior : destination.clipBehavior;
    if (clipBehavior != Clip.none) {
      canvas.save();
      _clipBoxDecoration(
        canvas,
        bounds,
        background,
        clipBehavior,
      );
      if (clipBehavior == Clip.antiAliasWithSaveLayer) {
        canvas.saveLayer(bounds, _saveLayerPaint ??= Paint());
      }
    }

    if (children.isNotEmpty) {
      final child = children.single;
      if (child._isVisible(progress)) {
        final childRect = child._rectAt(progress).shift(bounds.topLeft);
        child._paintChild(
          canvas,
          childRect,
          progress,
          owningBounds: bounds,
        );
      }
    }

    if (clipBehavior != Clip.none) {
      if (clipBehavior == Clip.antiAliasWithSaveLayer) canvas.restore();
      canvas.restore();
    }
    _paintContainerForeground(canvas, bounds, progress);
  }

  void _paintContainerBackground(
    Canvas canvas,
    Rect bounds,
    double progress,
  ) {
    final decoration = _backgroundDecorationAt(progress);
    if (decoration == null) return;
    _paintContainerDecoration(
      canvas,
      bounds,
      decoration,
      _backgroundPaint ??= Paint(),
    );
  }

  void _paintContainerForeground(
    Canvas canvas,
    Rect bounds,
    double progress,
  ) {
    final decoration = _foregroundDecorationAt(progress);
    if (decoration == null) return;
    _paintContainerDecoration(
      canvas,
      bounds,
      decoration,
      _foregroundPaint ??= Paint(),
    );
  }

  void _paintContainerDecoration(
    Canvas canvas,
    Rect bounds,
    BoxDecoration decoration,
    Paint paint,
  ) {
    if (_canPaintDirectly(decoration)) {
      _paintBoxDecoration(canvas, bounds, decoration, paint);
      return;
    }
    final painter = decoration.createBoxPainter();
    _paintDecorationPainter(painter, canvas, bounds);
    _disposeBoxPainter(painter);
  }

  void _paintDecorationPainter(
    BoxPainter painter,
    Canvas canvas,
    Rect bounds,
  ) {
    painter.paint(
      canvas,
      bounds.topLeft,
      ImageConfiguration(
        size: bounds.size,
        textDirection: textDirection,
      ),
    );
  }

  void _disposeBoxPainter(BoxPainter painter) {
    painter.dispose();
  }

  void _paintSelectedOrInterpolatedColumn(
    Canvas canvas,
    Rect bounds,
    double progress,
  ) {
    if (sourceColumn != null && destinationColumn != null) {
      _paintColumn(canvas, bounds, progress);
      return;
    }
    if (sourceColumn != null) {
      _paintColumn(canvas, bounds, 0);
      return;
    }
    if (destinationColumn != null) {
      _paintColumn(canvas, bounds, 1);
    }
  }

  void _paintColumn(Canvas canvas, Rect bounds, double progress) {
    _MorphCompoundFlightPlan? previousChild;
    var previousPaintBottom = 0.0;
    for (final child in children) {
      if (!child._isVisible(progress)) continue;
      final layoutRect = child._rectAt(progress);
      final previous = previousChild;
      final top = previous == null ? layoutRect.top : previousPaintBottom + child._columnGapAfter(previous, progress);
      final paintRect = Rect.fromLTWH(
        bounds.left + layoutRect.left,
        bounds.top + top,
        layoutRect.width,
        layoutRect.height,
      );
      final paintedHeight = child._paintChild(
        canvas,
        paintRect,
        progress,
        owningBounds: bounds,
      );
      previousChild = child;
      previousPaintBottom = top + paintedHeight;
    }
  }

  double _columnGapAfter(
    _MorphCompoundFlightPlan previous,
    double progress,
  ) {
    final source = sourceChild;
    final previousSource = previous.sourceChild;
    final destination = destinationChild;
    final previousDestination = previous.destinationChild;
    final sourceGap = source == null || previousSource == null ? null : source.rect.top - previousSource.rect.bottom;
    final destinationGap = destination == null || previousDestination == null
        ? null
        : destination.rect.top - previousDestination.rect.bottom;
    return switch ((sourceGap, destinationGap)) {
      (final double source, final double destination) => ui.lerpDouble(
        source,
        destination,
        progress,
      )!,
      (final double source, null) => source,
      (null, final double destination) => destination,
      _ => 0,
    };
  }

  bool _isVisible(double progress) {
    if (isRoot || (sourceChild != null && destinationChild != null)) {
      return true;
    }
    if (sourceChild != null) {
      return departureThresholdIsInclusive ? progress <= switchThreshold : progress < switchThreshold;
    }
    return progress >= switchThreshold;
  }

  Rect _rectAt(double progress) {
    final source = sourceChild;
    final destination = destinationChild;
    if (source != null && destination != null) {
      if (_rectIsStatic) return source.rect;
      return Rect.lerp(source.rect, destination.rect, progress)!;
    }
    return (source ?? destination)!.rect;
  }

  EdgeInsets _paddingAt(double progress) {
    final source = sourceChild;
    final destination = destinationChild;
    if (source != null && destination != null) {
      if (_paddingIsStatic) return source.padding;
      return EdgeInsets.lerp(
        source.padding,
        destination.padding,
        progress,
      )!;
    }
    return (source ?? destination)?.padding ?? EdgeInsets.zero;
  }

  void _paintBoxDecoration(
    Canvas canvas,
    Rect bounds,
    BoxDecoration decoration,
    Paint paint,
  ) {
    for (final shadow in decoration.boxShadow ?? const <BoxShadow>[]) {
      final shadowBounds = bounds.shift(shadow.offset).inflate(shadow.spreadRadius);
      assert(() {
        if (debugDisableShadows && shadow.blurStyle == BlurStyle.outer) {
          canvas
            ..save()
            ..clipRect(shadowBounds);
        }
        return true;
      }(), 'Disabled outer shadows should use Flutter BoxDecoration clipping.');
      _paintBoxShape(
        canvas,
        shadowBounds,
        decoration,
        shadow.toPaint(),
      );
      assert(() {
        if (debugDisableShadows && shadow.blurStyle == BlurStyle.outer) {
          canvas.restore();
        }
        return true;
      }(), 'Disabled outer shadows should restore their Flutter BoxDecoration clip.');
    }

    if (decoration.color != null || decoration.gradient != null) {
      paint
        ..color = decoration.color ?? const Color(0xFF000000)
        ..shader = decoration.gradient?.createShader(
          bounds,
          textDirection: textDirection,
        )
        ..blendMode = decoration.backgroundBlendMode ?? BlendMode.srcOver;
      _paintBoxShape(canvas, bounds, decoration, paint);
    }
    decoration.border?.paint(
      canvas,
      bounds,
      shape: decoration.shape,
      borderRadius: decoration.borderRadius?.resolve(textDirection),
      textDirection: textDirection,
    );
  }

  bool _canPaintDirectly(BoxDecoration decoration) {
    return decoration.image == null && decoration.border == null;
  }

  void _paintBoxShape(
    Canvas canvas,
    Rect bounds,
    BoxDecoration decoration,
    Paint paint,
  ) {
    if (decoration.shape == BoxShape.circle) {
      assert(
        decoration.borderRadius == null,
        'A circle cannot have a border radius. Remove either the shape or the borderRadius argument.',
      );
      canvas.drawCircle(
        bounds.center,
        bounds.shortestSide / 2,
        paint,
      );
      return;
    }
    final radius = decoration.borderRadius?.resolve(textDirection);
    if (radius == null || radius == BorderRadius.zero) {
      canvas.drawRect(bounds, paint);
      return;
    }
    canvas.drawRRect(radius.toRRect(bounds), paint);
  }

  void _clipBoxDecoration(
    Canvas canvas,
    Rect bounds,
    BoxDecoration? decoration,
    Clip clipBehavior,
  ) {
    final antiAlias = clipBehavior != Clip.hardEdge;
    if (decoration?.shape == BoxShape.circle) {
      canvas.clipPath(
        Path()..addOval(
          Rect.fromCircle(
            center: bounds.center,
            radius: bounds.shortestSide / 2,
          ),
        ),
        doAntiAlias: antiAlias,
      );
      return;
    }
    final radius = decoration?.borderRadius?.resolve(textDirection);
    if (radius == null || radius == BorderRadius.zero) {
      canvas.clipRect(bounds, doAntiAlias: antiAlias);
      return;
    }
    canvas.clipRRect(
      radius.toRRect(bounds),
      doAntiAlias: antiAlias,
    );
  }

  static TextStyle? _createTextRasterStyle(
    MorphChildProperties? sourceChild,
    MorphChildProperties? destinationChild,
  ) {
    final source = sourceChild?.text;
    final destination = destinationChild?.text;
    final endpoint = destination ?? source;
    return endpoint == null ? null : _MorphTextRasterCache.rasterStyle(endpoint.style);
  }

  static bool _haveEqualTextProperties(
    MorphChildProperties? sourceChild,
    MorphChildProperties? destinationChild,
  ) {
    final source = sourceChild?.text;
    final destination = destinationChild?.text;
    if (source == null || destination == null) return false;
    if (identical(source, destination)) return true;
    return source.text == destination.text &&
        source.style == destination.style &&
        source.textAlign == destination.textAlign &&
        source.textDirection == destination.textDirection &&
        source.locale == destination.locale &&
        source.softWrap == destination.softWrap &&
        source.overflow == destination.overflow &&
        source.textScaler == destination.textScaler &&
        source.maxLines == destination.maxLines &&
        source.semanticsLabel == destination.semanticsLabel &&
        source.textWidthBasis == destination.textWidthBasis &&
        source.textHeightBehavior == destination.textHeightBehavior &&
        source.strutStyle == destination.strutStyle &&
        source.selectionColor == destination.selectionColor &&
        source.switchThreshold == destination.switchThreshold &&
        source.measuredLineCount == destination.measuredLineCount &&
        source.longestLineWidth == destination.longestLineWidth &&
        source.lineHeight == destination.lineHeight &&
        source.baseline == destination.baseline &&
        source.layoutWidth == destination.layoutWidth &&
        source.estimatedHeight == destination.estimatedHeight &&
        source.paintStyle == destination.paintStyle &&
        source.paintScaleX == destination.paintScaleX &&
        source.paintScaleY == destination.paintScaleY &&
        source.endpointScaleX == destination.endpointScaleX &&
        source.endpointScaleY == destination.endpointScaleY &&
        source.baselineOffset == destination.baselineOffset &&
        source.reservedLayoutWidth == destination.reservedLayoutWidth;
  }

  static bool _haveEqualRects(
    MorphChildProperties? source,
    MorphChildProperties? destination,
  ) {
    if (source == null || destination == null) return false;
    return identical(source.rect, destination.rect) || source.rect == destination.rect;
  }

  static bool _haveEqualPadding(
    MorphChildProperties? source,
    MorphChildProperties? destination,
  ) {
    if (source == null || destination == null) return false;
    return identical(source.padding, destination.padding) || source.padding == destination.padding;
  }

  static bool _haveEqualBoxDecorations(
    Decoration? source,
    Decoration? destination,
  ) {
    if (source is! BoxDecoration || destination is! BoxDecoration) {
      return false;
    }
    return identical(source, destination) || source == destination;
  }

  static String? _createTextEndpointStyleBlocker(
    MorphChildProperties? sourceChild,
    MorphChildProperties? destinationChild,
  ) {
    final source = sourceChild?.text;
    final destination = destinationChild?.text;
    if (source == null || destination == null) return null;
    return _MorphTextRasterCache.endpointStyleBlocker(
      source: source,
      destination: destination,
    );
  }

  static double _createTextMaximumScale(
    MorphChildProperties? sourceChild,
    MorphChildProperties? destinationChild,
  ) {
    final source = sourceChild?.text;
    final destination = destinationChild?.text;
    if (source == null || destination == null) return 1;
    return _MorphTextRasterCache.maximumScale(
      source: source,
      destination: destination,
    );
  }

  static List<_MorphCompoundFlightPlan>? _containerChildren({
    required MorphContainerProperties source,
    required MorphContainerProperties destination,
    required TextDirection textDirection,
  }) {
    final sourceChild = source.child;
    final destinationChild = destination.child;
    if (sourceChild == null && destinationChild == null) {
      return const <_MorphCompoundFlightPlan>[];
    }
    final child = _forChild(
      source: sourceChild,
      destination: destinationChild,
      textDirection: textDirection,
      switchThreshold: source.switchThreshold,
      departureThresholdIsInclusive: false,
    );
    return child == null ? null : <_MorphCompoundFlightPlan>[child];
  }

  static List<_MorphCompoundFlightPlan>? _columnChildren({
    required MorphColumnProperties? source,
    required MorphColumnProperties? destination,
    required TextDirection textDirection,
  }) {
    if (source == null) {
      final plans = <_MorphCompoundFlightPlan>[];
      for (final child in destination!.children) {
        final plan = _forChild(
          source: child,
          destination: child,
          textDirection: textDirection,
          switchThreshold: destination.switchThreshold,
          departureThresholdIsInclusive: true,
        );
        if (plan == null) return null;
        plans.add(plan);
      }
      return plans;
    }
    if (destination == null) {
      final plans = <_MorphCompoundFlightPlan>[];
      for (final child in source.children) {
        final plan = _forChild(
          source: child,
          destination: child,
          textDirection: textDirection,
          switchThreshold: source.switchThreshold,
          departureThresholdIsInclusive: true,
        );
        if (plan == null) return null;
        plans.add(plan);
      }
      return plans;
    }

    final matching = _MorphColumnChildMatching(
      source: source.children,
      destination: destination.children,
    );

    final plans = <_MorphCompoundFlightPlan>[];
    for (var index = 0; index < source.children.length; index += 1) {
      final destinationIndex = matching.destinationIndexForSource(index);
      final plan = _forChild(
        source: source.children[index],
        destination: destinationIndex == null ? null : destination.children[destinationIndex],
        textDirection: textDirection,
        switchThreshold: source.switchThreshold,
        departureThresholdIsInclusive: true,
      );
      if (plan == null) return null;
      plans.add(plan);
    }
    for (var index = 0; index < destination.children.length; index += 1) {
      if (matching.isDestinationMatched(index)) continue;
      final plan = _forChild(
        source: null,
        destination: destination.children[index],
        textDirection: textDirection,
        switchThreshold: source.switchThreshold,
        departureThresholdIsInclusive: true,
      );
      if (plan == null) return null;
      plans.add(plan);
    }
    return plans;
  }

  static _MorphCompoundFlightPlan? _forChild({
    required MorphChildProperties? source,
    required MorphChildProperties? destination,
    required TextDirection textDirection,
    required double switchThreshold,
    required bool departureThresholdIsInclusive,
  }) {
    if (source != null && !_supportsChild(source)) return null;
    if (destination != null && !_supportsChild(destination)) return null;
    if (!_sameChildKind(source, destination)) return null;

    final sourceContainer = source?.container;
    final destinationContainer = destination?.container;
    final sourceColumn = source?.column;
    final destinationColumn = destination?.column;
    List<_MorphCompoundFlightPlan>? children;
    if (sourceContainer != null || destinationContainer != null) {
      if (sourceContainer != null && destinationContainer != null) {
        children = _containerChildren(
          source: sourceContainer,
          destination: destinationContainer,
          textDirection: textDirection,
        );
      } else {
        final selected = sourceContainer ?? destinationContainer!;
        final selectedChild = selected.child;
        if (selectedChild == null) {
          children = const <_MorphCompoundFlightPlan>[];
        } else {
          final child = _forChild(
            source: selectedChild,
            destination: selectedChild,
            textDirection: textDirection,
            switchThreshold: selected.switchThreshold,
            departureThresholdIsInclusive: false,
          );
          children = child == null ? null : <_MorphCompoundFlightPlan>[child];
        }
      }
    } else if (sourceColumn != null || destinationColumn != null) {
      children = _columnChildren(
        source: sourceColumn,
        destination: destinationColumn,
        textDirection: textDirection,
      );
    } else {
      children = const <_MorphCompoundFlightPlan>[];
    }
    if (children == null) return null;

    return _MorphCompoundFlightPlan._(
      textDirection: textDirection,
      sourceChild: source,
      destinationChild: destination,
      sourceContainer: sourceContainer,
      destinationContainer: destinationContainer,
      sourceColumn: sourceColumn,
      destinationColumn: destinationColumn,
      children: children,
      switchThreshold: switchThreshold,
      departureThresholdIsInclusive: departureThresholdIsInclusive,
      isRoot: false,
    );
  }

  static bool _supportsChild(MorphChildProperties child) {
    if (child.alignment != null) return false;
    final text = child.text;
    if (text != null) {
      return MorphTextFlightDelegate._supportsRetainedProperties(text);
    }
    final container = child.container;
    if (container != null) return _supportsContainer(container);
    final column = child.column;
    if (column != null) {
      return column.children.every(_supportsChild);
    }
    final widget = child.widget;
    return switch (widget) {
      SizedBox(child: null) => true,
      Align(child: null) => true,
      _ => false,
    };
  }

  static bool _supportsContainer(MorphContainerProperties container) {
    if (container.alignment != null) return false;
    if (!_supportsDecoration(container.decoration) || !_supportsDecoration(container.foregroundDecoration)) {
      return false;
    }
    final child = container.child;
    return child == null || _supportsChild(child);
  }

  static bool _supportsDecoration(Decoration? decoration) {
    if (decoration == null) return true;
    if (decoration is! BoxDecoration) return false;
    return decoration.image == null && decoration.border == null;
  }

  static bool _sameChildKind(
    MorphChildProperties? source,
    MorphChildProperties? destination,
  ) {
    if (source == null || destination == null) return true;
    return (source.text != null && destination.text != null) ||
        (source.container != null && destination.container != null) ||
        (source.column != null && destination.column != null) ||
        (MorphChildFlightDelegate._isEmptyLayoutWidget(source.widget) &&
            MorphChildFlightDelegate._isEmptyLayoutWidget(
              destination.widget,
            ));
  }
}
