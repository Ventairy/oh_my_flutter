part of '../motion.dart';

/// Paints animated graphemes from a shared glyph atlas.
class _RenderOptimizedTextMotion extends RenderBox with RelayoutWhenSystemFontsChangeMixin {
  new({
    required this._graphemes,
    required this._applications,
    required this._previewScale,
    required this._style,
    required this._strutStyle,
    required this._textAlign,
    required this._textDirection,
    required this._locale,
    required this._softWrap,
    required this._overflow,
    required this._textScaler,
    required this._maxLines,
    required this._textWidthBasis,
    required this._textHeightBehavior,
    required this._hyphens,
    required this._baseline,
    required this._devicePixelRatio,
    required this._attributedLabel,
    required this._semanticsIdentifier,
  }) : _renderEffects = _applications.map(_MotionRenderEffect.forText).toList(growable: false);

  static const int _maximumAtlasDimension = 2048;
  static const int _maximumAtlasPixels = 1024 * 1024;
  static const int _minimumEqualBlurGlyphs = 16;

  final _glyphBlur = _MotionBlur();
  Float64List? _glyphSigmas;
  _MotionPackedTextBlur? _packedBlur;
  late final _sparseBlur = _MotionSparseTextBlur();
  _MotionShaderTextBlur? _shaderBlur;
  bool _shaderBlurUnavailable = false;
  bool _paintedShaderBlur = false;
  final Paint _atlasPaint = Paint()..filterQuality = FilterQuality.low;
  final Paint _filteredAtlasPaint = Paint()..filterQuality = FilterQuality.low;
  final Paint _fallbackOpacityPaint = Paint();
  final Paint _overflowLayerPaint = Paint();
  final Paint _overflowShaderPaint = Paint()..blendMode = BlendMode.modulate;
  final MotionEffectTransform _effectTransform = MotionEffectTransform._();
  late final VoidCallback _animationListener = markNeedsPaint;
  late final AnimationStatusListener _atlasStatusListener = _prepareAtlasOnPlayback;

  List<String> _graphemes;
  List<_TextMotionApplication> _applications;
  double? _previewScale;
  List<_MotionRenderEffect> _renderEffects;
  TextStyle _style;
  StrutStyle? _strutStyle;
  TextAlign _textAlign;
  TextDirection _textDirection;
  Locale? _locale;
  bool _softWrap;
  TextOverflow _overflow;
  TextScaler _textScaler;
  int? _maxLines;
  TextWidthBasis _textWidthBasis;
  ui.TextHeightBehavior? _textHeightBehavior;
  ui.Hyphens _hyphens;
  TextBaseline _baseline;
  double _devicePixelRatio;
  AttributedString _attributedLabel;
  String? _semanticsIdentifier;

  TextPainter? _textPainter;
  List<TextPainter> _glyphPainters = const <TextPainter>[];
  List<ui.TextBox> _placeholderBoxes = const <ui.TextBox>[];
  List<int> _spriteIndexByCharacter = const <int>[];
  List<_TextMotionSprite> _sprites = const <_TextMotionSprite>[];
  ui.Image? _atlas;
  Float32List? _atlasRects;
  Float32List? _atlasTransforms;
  Int32List? _atlasColors;
  Float64List? _characterCenters;
  Float64List? _spriteAnchors;
  bool _atlasDisabled = false;
  int? _firstOversizedAtlasGlyphCount;
  bool _atlasDeferred = false;
  bool _needsClipping = false;
  bool _paintsParagraph = false;
  ui.Shader? _overflowShader;
  double _computedOpacity = 1;
  double _computedBlurSigma = 0;
  double _computedScale = 1;
  double _computedCosine = 1;
  double _computedSine = 0;
  double _computedTranslationX = 0;
  double _computedTranslationY = 0;
  Rect _cachedPaintBounds = Rect.zero;

  @override
  bool get isRepaintBoundary => true;

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  Rect get paintBounds => _cachedPaintBounds;

  void _updatePaintBounds() {
    if (_needsClipping) {
      _cachedPaintBounds = Offset.zero & size;
      return;
    }

    if (_renderEffects.every((effect) => effect.bounds.maximumRotationDegrees == 0)) {
      _cachedPaintBounds = _MotionRenderEffect.paintBoundsFor(size, _renderEffects.map((effect) => effect.bounds));
      return;
    }

    var bounds = Offset.zero & size;
    final paintCount = math.min(_placeholderBoxes.length, _spriteIndexByCharacter.length);
    for (var index = 0; index < paintCount; index += 1) {
      final box = _placeholderBoxes[index];
      final characterBounds = _MotionRenderEffect.paintBoundsFor(
        Size(box.right - box.left, box.bottom - box.top),
        _renderEffects.map((effect) => effect.bounds),
      ).shift(Offset(box.left, box.top));
      bounds = bounds.expandToInclude(characterBounds);
    }
    _cachedPaintBounds = bounds;
  }

  void updateConfiguration({
    required List<String> graphemes,
    required List<_TextMotionApplication> applications,
    required double? previewScale,
    required TextStyle style,
    required StrutStyle? strutStyle,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required Locale? locale,
    required bool softWrap,
    required TextOverflow overflow,
    required TextScaler textScaler,
    required int? maxLines,
    required TextWidthBasis textWidthBasis,
    required ui.TextHeightBehavior? textHeightBehavior,
    required ui.Hyphens hyphens,
    required TextBaseline baseline,
    required double devicePixelRatio,
    required AttributedString attributedLabel,
    required String? semanticsIdentifier,
  }) {
    final semanticsChanged =
        _attributedLabel != attributedLabel ||
        _semanticsIdentifier != semanticsIdentifier ||
        _textDirection != textDirection;
    final layoutChanged =
        !listEquals(_graphemes, graphemes) ||
        _style != style ||
        _strutStyle != strutStyle ||
        _textAlign != textAlign ||
        _textDirection != textDirection ||
        _locale != locale ||
        _softWrap != softWrap ||
        _overflow != overflow ||
        _textScaler != textScaler ||
        _maxLines != maxLines ||
        _textWidthBasis != textWidthBasis ||
        _textHeightBehavior != textHeightBehavior ||
        _hyphens != hyphens ||
        _baseline != baseline ||
        _devicePixelRatio != devicePixelRatio;
    if (layoutChanged) {
      _graphemes = graphemes;
      _style = style;
      _strutStyle = strutStyle;
      _textAlign = textAlign;
      _textDirection = textDirection;
      _locale = locale;
      _softWrap = softWrap;
      _overflow = overflow;
      _textScaler = textScaler;
      _maxLines = maxLines;
      _textWidthBasis = textWidthBasis;
      _textHeightBehavior = textHeightBehavior;
      _hyphens = hyphens;
      _baseline = baseline;
      _devicePixelRatio = devicePixelRatio;
      _clearTextResources();
      markNeedsLayout();
    }

    if (_previewScale != previewScale) {
      _previewScale = previewScale;
      markNeedsPaint();
    }
    if (!listEquals(_applications, applications)) {
      _replaceApplications(applications);
    }

    if (semanticsChanged) {
      _attributedLabel = attributedLabel;
      _semanticsIdentifier = semanticsIdentifier;
      markNeedsSemanticsUpdate();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _attachAnimations();
  }

  @override
  void detach() {
    _detachAnimations();
    super.detach();
  }

  @override
  void systemFontsDidChange() {
    super.systemFontsDidChange();
    _clearTextResources();
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    final painter = _prepareText();
    return (painter..layout()).minIntrinsicWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final painter = _prepareText();
    return (painter..layout()).maxIntrinsicWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _intrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _intrinsicHeight(width);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final painter = _prepareText();
    _layoutPainter(painter, constraints);
    return constraints.constrain(painter.size);
  }

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    final painter = _prepareText();
    _layoutPainter(painter, constraints);
    return painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  }

  @override
  double computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final painter = _prepareText();
    _layoutPainter(painter, constraints);
    return painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  }

  @override
  void performLayout() {
    final painter = _prepareText();
    _layoutPainter(painter, constraints);
    final textSize = painter.size;
    size = constraints.constrain(textSize);
    _placeholderBoxes = painter.inlinePlaceholderBoxes ?? const <ui.TextBox>[];
    if (!_atlasDeferred) _buildAtlas();
    _preparePaintBuffers();
    _configureOverflow(textSize, painter.didExceedMaxLines);
    _updatePaintBounds();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _paintContent(context.canvas, offset);
  }

  void _paintContent(Canvas canvas, Offset offset, {bool applyBlur = true}) {
    final painter = _textPainter;
    if (painter == null) return;
    if (_atlasDeferred) {
      if (applyBlur && !_paintsParagraph && _isHiddenWhileWaiting) return;
      _prepareDeferredAtlas();
    }
    if (_needsClipping) {
      final bounds = offset & size;
      if (_overflowShader == null) {
        canvas.save();
      } else {
        canvas.saveLayer(bounds, _overflowLayerPaint);
      }
      canvas.clipRect(bounds);
    }

    if (_paintsParagraph) {
      painter.paint(canvas, offset);
    }
    final atlas = _atlas;
    if (atlas == null) {
      _paintGlyphsWithoutAtlas(canvas, offset, applyBlur: applyBlur);
    } else {
      _paintAtlas(canvas, atlas, offset, applyBlur: applyBlur);
    }

    if (_needsClipping) {
      final shader = _overflowShader;
      if (shader != null) {
        _overflowShaderPaint.shader = shader;
        canvas
          ..translate(offset.dx, offset.dy)
          ..drawRect(Offset.zero & size, _overflowShaderPaint);
      }
      canvas.restore();
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..attributedLabel = _attributedLabel
      ..textDirection = _textDirection;
    final semanticsIdentifier = _semanticsIdentifier;
    if (semanticsIdentifier != null) {
      config.identifier = semanticsIdentifier;
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    _prepareMotionFrame();
    final states = List.generate(
      _spriteIndexByCharacter.length,
      (index) {
        _computeMotionState();
        return (
          opacity: _computedOpacity,
          scale: _computedScale,
          rotation: _effectTransform._rotationDegrees,
          translationX: _computedTranslationX,
          translationY: _computedTranslationY,
        );
      },
      growable: false,
    );
    properties
      ..add(IntProperty('animatedCharacterCount', states.length))
      ..add(
        FlagProperty(
          'glyphBlurProgram',
          value: _MotionShaderTextBlur.prepared != null,
          ifTrue: 'glyph blur shader warmed',
        ),
      )
      ..add(FlagProperty('glyphBlurShader', value: _paintedShaderBlur, ifTrue: 'glyph blur shader was used'))
      ..add(IterableProperty<String>('graphemes', _graphemes))
      ..add(
        IterableProperty<String>(
          'effects',
          _renderEffects.map(
            (effect) => effect.effect.runtimeType.toString(),
          ),
        ),
      )
      ..add(
        IterableProperty<double>(
          'characterOpacities',
          states.map((state) => state.opacity),
        ),
      )
      ..add(
        IterableProperty<double>(
          'characterScales',
          states.map((state) => state.scale),
        ),
      )
      ..add(
        IterableProperty<double>(
          'characterRotations',
          states.map((state) => state.rotation),
        ),
      )
      ..add(
        IterableProperty<Offset>(
          'characterTranslations',
          states.map(
            (state) => Offset(state.translationX, state.translationY),
          ),
        ),
      )
      ..add(DiagnosticsProperty<TextStyle>('style', _style))
      ..add(DiagnosticsProperty<StrutStyle>('strutStyle', _strutStyle))
      ..add(EnumProperty<TextAlign>('textAlign', _textAlign))
      ..add(EnumProperty<TextDirection>('textDirection', _textDirection))
      ..add(DiagnosticsProperty<Locale>('locale', _locale))
      ..add(FlagProperty('softWrap', value: _softWrap, ifTrue: 'enabled'))
      ..add(EnumProperty<TextOverflow>('overflow', _overflow))
      ..add(DiagnosticsProperty<TextScaler>('textScaler', _textScaler))
      ..add(IntProperty('maxLines', _maxLines))
      ..add(EnumProperty<TextWidthBasis>('textWidthBasis', _textWidthBasis))
      ..add(
        DiagnosticsProperty<ui.TextHeightBehavior>(
          'textHeightBehavior',
          _textHeightBehavior,
        ),
      )
      ..add(EnumProperty<ui.Hyphens>('hyphens', _hyphens))
      ..add(EnumProperty<TextBaseline>('baseline', _baseline))
      ..add(
        FlagProperty(
          'paintsParagraph',
          value: _paintsParagraph,
          ifTrue: 'yes',
        ),
      )
      ..add(FlagProperty('usesAtlas', value: _atlas != null, ifTrue: 'yes'));
  }

  @override
  void dispose() {
    _clearTextResources();
    super.dispose();
  }

  double _intrinsicHeight(double width) {
    final painter = _prepareText();
    return (painter..layout(minWidth: width, maxWidth: _adjustMaxWidth(width))).height;
  }

  double _adjustMaxWidth(double maxWidth) {
    return _softWrap || _overflow == TextOverflow.ellipsis ? maxWidth : double.infinity;
  }

  void _layoutPainter(TextPainter painter, BoxConstraints constraints) {
    painter.layout(
      minWidth: constraints.minWidth,
      maxWidth: _adjustMaxWidth(constraints.maxWidth),
    );
  }

  TextPainter _prepareText() {
    final cachedPainter = _textPainter;
    if (cachedPainter != null) {
      return cachedPainter;
    }

    final spans = <InlineSpan>[];
    final dimensions = <PlaceholderDimensions>[];
    final glyphPainters = <TextPainter>[];
    final uniqueGlyphs = <String, int>{};
    final spriteIndexByCharacter = <int>[];
    for (final grapheme in _graphemes) {
      if (!_TextMotionTransition.isVisible(grapheme)) {
        spans.add(TextSpan(text: grapheme));
        continue;
      }

      var spriteIndex = uniqueGlyphs[grapheme];
      if (spriteIndex == null) {
        spriteIndex = glyphPainters.length;
        uniqueGlyphs[grapheme] = spriteIndex;
        glyphPainters.add(_createGlyphPainter(grapheme)..layout());
      }
      final glyphPainter = glyphPainters[spriteIndex];
      spriteIndexByCharacter.add(spriteIndex);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: _baseline,
          child: const SizedBox.shrink(),
        ),
      );
      dimensions.add(
        PlaceholderDimensions(
          size: glyphPainter.size,
          alignment: PlaceholderAlignment.baseline,
          baseline: _baseline,
          baselineOffset: glyphPainter.computeDistanceToActualBaseline(
            _baseline,
          ),
        ),
      );
    }

    final painter = TextPainter(
      text: TextSpan(
        style: _style,
        locale: _locale,
        children: spans,
      ),
      textAlign: _textAlign,
      textDirection: _textDirection,
      textScaler: _textScaler,
      maxLines: _maxLines,
      ellipsis: _overflow == TextOverflow.ellipsis ? '\u2026' : null,
      locale: _locale,
      strutStyle: _strutStyle,
      textWidthBasis: _textWidthBasis,
      textHeightBehavior: _textHeightBehavior,
      hyphens: _hyphens,
    )..setPlaceholderDimensions(dimensions);
    _textPainter = painter;
    _glyphPainters = glyphPainters;
    _spriteIndexByCharacter = spriteIndexByCharacter;
    if (_isHiddenWhileWaiting) {
      _setAtlasDeferred(true);
    }
    return painter;
  }

  bool get _isHiddenWhileWaiting {
    // A disintegration preview may still need a sharp source for capture.
    if (_previewScale != null ||
        !_renderEffects.any((effect) => effect.bounds.maximumBlurSigma > 0) ||
        _renderEffects.any((effect) => !effect.animation.status.isDismissed)) {
      return false;
    }
    _prepareMotionFrame();
    _computeMotionState();
    return _computedOpacity <= 0 && _computedBlurSigma > 0;
  }

  void _setAtlasDeferred(bool deferred) {
    if (_atlasDeferred == deferred) return;
    _atlasDeferred = deferred;
    if (!attached) return;
    for (final effect in _renderEffects) {
      if (deferred) {
        effect.animation.addStatusListener(_atlasStatusListener);
      } else {
        effect.animation.removeStatusListener(_atlasStatusListener);
      }
    }
  }

  void _prepareAtlasOnPlayback(AnimationStatus status) {
    if (status.isAnimating) _prepareDeferredAtlas();
  }

  void _prepareDeferredAtlas() {
    if (!_atlasDeferred) return;
    _setAtlasDeferred(false);
    _buildAtlas();
    _preparePaintBuffers();
  }

  TextPainter _createGlyphPainter(String grapheme) {
    return TextPainter(
      text: TextSpan(text: grapheme, style: _style, locale: _locale),
      textDirection: _textDirection,
      textScaler: _textScaler,
      maxLines: 1,
      locale: _locale,
      strutStyle: _strutStyle,
      textWidthBasis: TextWidthBasis.longestLine,
      textHeightBehavior: _textHeightBehavior,
      hyphens: _hyphens,
    );
  }

  void _buildAtlas() {
    if (_atlasDisabled || _sprites.length == _glyphPainters.length) return;

    final paintCount = math.min(_placeholderBoxes.length, _spriteIndexByCharacter.length);
    var glyphCount = _glyphPainters.length;
    if (paintCount < _spriteIndexByCharacter.length) {
      // Sprite indices follow first appearance. The visible text needs
      // only the prefix through the highest index it references.
      glyphCount = 0;
      for (var index = 0; index < paintCount; index++) {
        glyphCount = math.max(glyphCount, _spriteIndexByCharacter[index] + 1);
      }
    }
    if (glyphCount <= _sprites.length) return;
    final oversizedCount = _firstOversizedAtlasGlyphCount;
    if (oversizedCount != null && glyphCount >= oversizedCount) {
      _discardAtlas();
      return;
    }

    final padding = _atlasPadding;
    final paddingPixels = (padding * _devicePixelRatio).ceil();
    final sprites = <_TextMotionSprite>[];
    var x = 0;
    var y = 0;
    var rowHeight = 0;
    var atlasWidth = 0;
    for (var index = 0; index < glyphCount; index++) {
      final painter = _glyphPainters[index];
      final glyphWidth = (painter.width * _devicePixelRatio).ceil();
      final glyphHeight = (painter.height * _devicePixelRatio).ceil();
      final spriteWidth = math.max(1, glyphWidth + paddingPixels * 2);
      final spriteHeight = math.max(1, glyphHeight + paddingPixels * 2);
      if (spriteWidth > _maximumAtlasDimension || spriteHeight > _maximumAtlasDimension) {
        _noteAtlasTooLarge(index + 1);
        return;
      }
      if (x > 0 && x + spriteWidth > _maximumAtlasDimension) {
        x = 0;
        y += rowHeight;
        rowHeight = 0;
      }
      if (y + spriteHeight > _maximumAtlasDimension) {
        _noteAtlasTooLarge(index + 1);
        return;
      }
      sprites.add((
        left: x.toDouble(),
        top: y.toDouble(),
        right: (x + spriteWidth).toDouble(),
        bottom: (y + spriteHeight).toDouble(),
        anchorX: paddingPixels + painter.width * _devicePixelRatio / 2,
        anchorY: paddingPixels + painter.height * _devicePixelRatio / 2,
      ));
      x += spriteWidth;
      rowHeight = math.max(rowHeight, spriteHeight);
      atlasWidth = math.max(atlasWidth, x);
    }
    final atlasHeight = y + rowHeight;
    if (atlasWidth * atlasHeight > _maximumAtlasPixels) {
      _noteAtlasTooLarge(glyphCount);
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_devicePixelRatio, _devicePixelRatio);
    for (var index = 0; index < glyphCount; index += 1) {
      final sprite = sprites[index];
      final left = sprite.left / _devicePixelRatio;
      final top = sprite.top / _devicePixelRatio;
      final right = sprite.right / _devicePixelRatio;
      final bottom = sprite.bottom / _devicePixelRatio;
      canvas
        ..save()
        ..clipRect(Rect.fromLTRB(left, top, right, bottom));
      _glyphPainters[index].paint(
        canvas,
        Offset(
          left + paddingPixels / _devicePixelRatio,
          top + paddingPixels / _devicePixelRatio,
        ),
      );
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final ui.Image atlas;
    try {
      atlas = picture.toImageSync(atlasWidth, atlasHeight);
    } finally {
      picture.dispose();
    }
    _discardAtlas();
    _atlas = atlas;
    _sprites = sprites;
  }

  void _noteAtlasTooLarge(int glyphCount) {
    _firstOversizedAtlasGlyphCount = glyphCount;
    _discardAtlas();
  }

  void _discardAtlas() {
    _shaderBlur?.dispose();
    _shaderBlur = null;
    _atlas?.dispose();
    _atlas = null;
    _sprites = const <_TextMotionSprite>[];
  }

  double get _atlasPadding {
    var padding = math.max(2 / _devicePixelRatio, (_style.fontSize ?? kDefaultFontSize) * 0.2);
    final shadows = _style.shadows;
    if (shadows == null) {
      return padding;
    }
    for (final shadow in shadows) {
      padding = math.max(
        padding,
        shadow.blurRadius * 2 + math.max(shadow.offset.dx.abs(), shadow.offset.dy.abs()),
      );
    }
    return padding;
  }

  void _preparePaintBuffers() {
    final paintCount = math.min(
      _placeholderBoxes.length,
      _spriteIndexByCharacter.length,
    );
    final centerBufferLength = paintCount * 2;
    if (_characterCenters?.length != centerBufferLength) {
      _characterCenters = Float64List(centerBufferLength);
      _spriteAnchors = Float64List(centerBufferLength);
    }
    final centers = _characterCenters!;
    final anchors = _spriteAnchors!;
    for (var index = 0; index < paintCount; index += 1) {
      final box = _placeholderBoxes[index];
      final centerIndex = index * 2;
      centers[centerIndex] = (box.left + box.right) / 2;
      centers[centerIndex + 1] = (box.top + box.bottom) / 2;
      if (_atlas != null) {
        final sprite = _sprites[_spriteIndexByCharacter[index]];
        anchors[centerIndex] = sprite.anchorX;
        anchors[centerIndex + 1] = sprite.anchorY;
      }
    }
    if (_atlas == null) {
      _atlasRects = null;
      _atlasTransforms = null;
      _atlasColors = null;
      return;
    }
    final bufferLength = paintCount * 4;
    if (_atlasRects?.length != bufferLength) {
      _atlasRects = Float32List(bufferLength);
      _atlasTransforms = Float32List(bufferLength);
    }
    if (_atlasColors?.length != paintCount) {
      _atlasColors = Int32List(paintCount);
      _glyphSigmas = null;
      _packedBlur = null;
    }
    final rects = _atlasRects!;
    for (var index = 0; index < paintCount; index += 1) {
      final sprite = _sprites[_spriteIndexByCharacter[index]];
      final bufferIndex = index * 4;
      rects[bufferIndex] = sprite.left;
      rects[bufferIndex + 1] = sprite.top;
      rects[bufferIndex + 2] = sprite.right;
      rects[bufferIndex + 3] = sprite.bottom;
    }
  }

  void _paintAtlas(Canvas canvas, ui.Image atlas, Offset offset, {required bool applyBlur}) {
    _paintedShaderBlur = false;
    final rects = _atlasRects;
    final transforms = _atlasTransforms;
    if (rects == null || transforms == null || rects.isEmpty) {
      return;
    }
    final colors = _atlasColors!;
    final centers = _characterCenters!;
    final anchors = _spriteAnchors!;
    final paintCount = centers.length ~/ 2;
    final inverseDevicePixelRatio = 1 / _devicePixelRatio;
    final offsetX = offset.dx;
    final offsetY = offset.dy;
    var usesOpacity = false;
    var filterRuns = 0;
    var previousSigma = 0.0;
    _prepareMotionFrame();
    for (var index = 0; index < paintCount; index += 1) {
      _computeMotionState();
      final bufferIndex = index * 4;
      final centerIndex = index * 2;
      final rasterScale = _computedScale * inverseDevicePixelRatio;
      final scaledCosine = rasterScale * _computedCosine;
      final scaledSine = rasterScale * _computedSine;
      transforms[bufferIndex] = scaledCosine;
      transforms[bufferIndex + 1] = scaledSine;
      transforms[bufferIndex + 2] =
          offsetX +
          centers[centerIndex] +
          _computedTranslationX -
          scaledCosine * anchors[centerIndex] +
          scaledSine * anchors[centerIndex + 1];
      transforms[bufferIndex + 3] =
          offsetY +
          centers[centerIndex + 1] +
          _computedTranslationY -
          scaledSine * anchors[centerIndex] -
          scaledCosine * anchors[centerIndex + 1];
      final alpha = _computedOpacity >= 1 ? 255 : (_computedOpacity.clamp(0.0, 1.0) * 255).round();
      colors[index] = alpha << 24;
      usesOpacity = usesOpacity || alpha < 255;
      final sigma = applyBlur && alpha > 0 && rasterScale != 0 ? _computedBlurSigma : 0.0;
      if (sigma > 0) {
        _glyphSigmas ??= Float64List(paintCount);
        if (sigma != previousSigma) filterRuns++;
      }
      previousSigma = sigma;
      _glyphSigmas?[index] = sigma;
    }

    final atlasColors = usesOpacity ? colors : null;
    try {
      if (filterRuns > 0) {
        _paintFilteredAtlas(canvas, atlas, transforms, rects, atlasColors, filterRuns: filterRuns);
        return;
      }
      _paintGlyphAtlasRange(canvas, atlas, transforms, rects, atlasColors, start: 0, end: paintCount);
    } on ui.PictureRasterizationException {
      _discardAtlas();
      _atlasDisabled = true;
      _paintGlyphsWithoutAtlas(canvas, offset, applyBlur: applyBlur);
    }
  }

  void _paintGlyphAtlasRange(
    Canvas canvas,
    ui.Image atlas,
    Float32List transforms,
    Float32List rects,
    Int32List? colors, {
    required int start,
    required int end,
    double sigma = 0,
  }) {
    var first = start;
    var stop = end;
    if (sigma == 0 && colors != null) {
      while (first < stop && colors[first] == 0) {
        first++;
      }
      if (first == stop) return;
      while (colors[stop - 1] == 0) {
        stop--;
      }
    }

    final paint = sigma > 0 ? (_filteredAtlasPaint..imageFilter = _glyphBlur.filter(sigma)) : _atlasPaint;
    if (first == 0 && stop * 4 == rects.length) {
      canvas.drawRawAtlas(atlas, transforms, rects, colors, colors == null ? null : BlendMode.srcIn, null, paint);
      return;
    }
    _MotionBlur.drawAtlasRange(canvas, atlas, transforms, rects, colors, paint, start: first, end: stop);
  }

  void _paintFilteredAtlas(
    Canvas canvas,
    ui.Image atlas,
    Float32List transforms,
    Float32List rects,
    Int32List? colors, {
    required int filterRuns,
  }) {
    final sigmas = _glyphSigmas!;
    // Reuse the warmed shader for the last few glyphs instead of issuing
    // a separate filter pass for each remaining strength.
    final useShader =
        filterRuns >= _MotionPackedTextBlur.minimumFilters ||
        (_MotionShaderTextBlur.prepared != null && _hasFewBlurredGlyphs(sigmas));
    if (useShader && _paintShaderBlur(canvas, atlas, transforms, rects, colors, sigmas)) {
      return;
    }
    final packer = filterRuns >= _MotionPackedTextBlur.minimumFilters
        ? _packedBlur ??= _MotionPackedTextBlur(sigmas.length)
        : null;
    final packed = packer?.prepare(atlas, sigmas, transforms, rects, colors);
    try {
      var start = 0;
      while (start < sigmas.length) {
        var end = start + 1;
        if (packed != null && packer!.includes(start)) {
          while (end < sigmas.length && packer.includes(end)) {
            end++;
          }
          packer.paint(canvas, packed, _atlasPaint, startGlyph: start, endGlyph: end, usesOpacity: colors != null);
        } else {
          final sigma = sigmas[start];
          while (end < sigmas.length && sigmas[end] == sigma && (packed == null || !packer!.includes(end))) {
            end++;
          }
          final sigmaInPixels = sigma * _devicePixelRatio;
          if (sigma > 0 &&
              sigmaInPixels <= _MotionSparseTextBlur.maximumSigmaInPixels &&
              end == start + 1 &&
              _canUseShaderBlur &&
              _sparseBlur.paint(
                canvas,
                atlas,
                transforms,
                rects,
                colors,
                _atlasPaint,
                glyph: start,
                sigmaInPixels: sigmaInPixels,
                devicePixelRatio: _devicePixelRatio,
              )) {
            start = end;
            continue;
          }
          _paintGlyphAtlasRange(canvas, atlas, transforms, rects, colors, start: start, end: end, sigma: sigma);
        }
        start = end;
      }
    } finally {
      packed?.dispose();
    }
  }

  bool _hasFewBlurredGlyphs(Float64List sigmas) {
    var count = 0;
    for (final sigma in sigmas) {
      if (sigma > 0 && ++count >= _MotionPackedTextBlur.minimumFilters) return false;
    }
    return true;
  }

  // Custom paint and shadows can reach the edges of a padded atlas sprite.
  bool get _canUseShaderBlur =>
      !_shaderBlurUnavailable &&
      _style.foreground == null &&
      _style.background == null &&
      _style.backgroundColor == null &&
      !(_style.shadows?.isNotEmpty ?? false);

  bool _paintShaderBlur(
    Canvas canvas,
    ui.Image atlas,
    Float32List transforms,
    Float32List rects,
    Int32List? colors,
    Float64List sigmas,
  ) {
    if (!_canUseShaderBlur) return false;

    final prepared = _MotionShaderTextBlur.prepared;
    if (prepared == null) {
      _MotionShaderTextBlur.requestWarmUp(devicePixelRatio: _devicePixelRatio);
      return false;
    }

    final _MotionShaderTextBlur shader;
    try {
      shader = _shaderBlur ??= _MotionShaderTextBlur(
        prepared.program,
        atlas,
        useMesh: prepared.useMesh,
        paddingPixels: (_atlasPadding * _devicePixelRatio).ceilToDouble(),
      );
    } on Exception {
      _shaderBlurUnavailable = true;
      return false;
    }
    if (!shader.available) {
      shader.dispose();
      _shaderBlur = null;
      _shaderBlurUnavailable = true;
      return false;
    }

    if (!shader.prepare(transforms, rects, sigmas)) return false;

    var glyph = 0;
    var equalRunEnd = 0;
    while (glyph < sigmas.length) {
      final sigma = sigmas[glyph];
      if (sigma > 0 && glyph >= equalRunEnd) {
        equalRunEnd = glyph + 1;
        while (equalRunEnd < sigmas.length && sigmas[equalRunEnd] == sigma) {
          equalRunEnd++;
        }
        if (equalRunEnd - glyph >= _minimumEqualBlurGlyphs &&
            _isCompactBlurRun(transforms, rects, start: glyph, end: equalRunEnd, sigma: sigma)) {
          shader.flush(canvas);
          _MotionBlur.drawAtlasRange(
            canvas,
            atlas,
            transforms,
            rects,
            colors,
            _filteredAtlasPaint..imageFilter = _glyphBlur.filter(sigma),
            start: glyph,
            end: equalRunEnd,
          );
          glyph = equalRunEnd;
          continue;
        }
      }
      final level = shader.sampleLevel(glyph);
      if (level >= 0) {
        final alpha = colors == null ? 255 : (colors[glyph] >> 24) & 255;
        if (shader.paint(canvas, transforms, rects, glyph, sigma, alpha / 255, level: level)) {
          _paintedShaderBlur = true;
          glyph++;
          continue;
        }
      }

      var end = glyph + 1;
      while (end < sigmas.length && sigmas[end] == sigma && (!shader.available || shader.sampleLevel(end) < 0)) {
        end++;
      }
      shader.flush(canvas);
      _paintGlyphAtlasRange(canvas, atlas, transforms, rects, colors, start: glyph, end: end, sigma: sigma);
      glyph = end;
    }
    shader.flush(canvas);
    return true;
  }

  static bool _isCompactBlurRun(
    Float32List transforms,
    Float32List rects, {
    required int start,
    required int end,
    required double sigma,
  }) {
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    var spriteArea = 0.0;
    final halo = 2 * _MotionBlur.outset(sigma);
    for (var index = start * 4; index < end * 4; index += 4) {
      final scale = transforms[index];
      if (scale <= 0 || transforms[index + 1] != 0) return false;
      final x = transforms[index + 2];
      final y = transforms[index + 3];
      final width = (rects[index + 2] - rects[index]) * scale;
      final height = (rects[index + 3] - rects[index + 1]) * scale;
      left = math.min(left, x);
      top = math.min(top, y);
      right = math.max(right, x + width);
      bottom = math.max(bottom, y + height);
      spriteArea += (width + halo) * (height + halo);
    }

    // A shared layer is wasteful when glyphs are scattered across the canvas.
    return (right - left + halo) * (bottom - top + halo) <= spriteArea;
  }

  void _paintGlyphsWithoutAtlas(Canvas canvas, Offset offset, {required bool applyBlur}) {
    final centers = _characterCenters;
    if (centers == null) {
      return;
    }
    final paintCount = centers.length ~/ 2;
    final offsetX = offset.dx;
    final offsetY = offset.dy;
    _prepareMotionFrame();
    for (var index = 0; index < paintCount; index += 1) {
      _computeMotionState();
      if (_computedOpacity <= 0 || _computedScale == 0 || !_computedScale.isFinite) {
        continue;
      }
      final centerIndex = index * 2;
      final painter = _glyphPainters[_spriteIndexByCharacter[index]];
      final x = offsetX + centers[centerIndex] + _computedTranslationX;
      final y = offsetY + centers[centerIndex + 1] + _computedTranslationY;
      final sigma = applyBlur ? _computedBlurSigma : 0.0;
      if (sigma > 0) {
        final scale = _computedScale.abs();
        final cosine = _computedCosine.abs();
        final sine = _computedSine.abs();
        _glyphBlur.save(
          canvas,
          Rect.fromCenter(
            center: Offset(x, y),
            width: scale * (cosine * painter.width + sine * painter.height),
            height: scale * (sine * painter.width + cosine * painter.height),
          ),
          sigma,
        );
      }
      canvas
        ..save()
        ..translate(x, y);
      if (_computedSine != 0 || _computedCosine != 1) {
        canvas.rotate(math.atan2(_computedSine, _computedCosine));
      }
      canvas
        ..scale(_computedScale, _computedScale)
        ..translate(-painter.width / 2, -painter.height / 2);
      final opacity = _computedOpacity.clamp(0.0, 1.0);
      if (opacity < 1) {
        _fallbackOpacityPaint.color = Color.fromRGBO(255, 255, 255, opacity);
        canvas.saveLayer(Offset.zero & painter.size, _fallbackOpacityPaint);
      }
      painter.paint(canvas, Offset.zero);
      if (opacity < 1) {
        canvas.restore();
      }
      canvas.restore();
      if (sigma > 0) canvas.restore();
    }
  }

  void _computeMotionState() {
    _effectTransform._reset();
    for (var effectIndex = 0; effectIndex < _renderEffects.length; effectIndex += 1) {
      final effect = _renderEffects[effectIndex];
      effect.effect.apply(effect.nextProgress(), _effectTransform);
    }
    final previewScale = _previewScale;
    if (previewScale == null) {
      _computedBlurSigma = _effectTransform._blurSigma;
    } else {
      _effectTransform._finishOperations();
      _computedBlurSigma = previewScale > 0 ? _effectTransform._previewBlurSigma / previewScale : 0;
      _effectTransform._resetTransform();
    }
    _computedOpacity = _effectTransform._opacity;
    _computedScale = _effectTransform._scale;
    _computedCosine = _effectTransform._cosine;
    _computedSine = _effectTransform._sine;
    _computedTranslationX = _effectTransform._translationX;
    _computedTranslationY = _effectTransform._translationY;
  }

  void _prepareMotionFrame() {
    for (var index = 0; index < _renderEffects.length; index += 1) {
      _renderEffects[index].prepareFrame();
    }
  }

  void _configureOverflow(Size textSize, bool didExceedMaxLines) {
    _overflowShader = null;
    _paintsParagraph =
        (_hyphens == ui.Hyphens.manual && _graphemes.contains('\u00AD')) ||
        _style.background != null ||
        _style.backgroundColor != null ||
        (_style.decoration != null && _style.decoration != TextDecoration.none) ||
        (_overflow == TextOverflow.ellipsis && didExceedMaxLines);
    final didOverflowHeight = size.height < textSize.height || didExceedMaxLines;
    final didOverflowWidth = size.width < textSize.width;
    if (!didOverflowHeight && !didOverflowWidth) {
      _needsClipping = false;
      return;
    }
    if (_overflow == TextOverflow.visible) {
      _needsClipping = false;
      return;
    }
    _needsClipping = true;
    if (_overflow != TextOverflow.fade) {
      return;
    }

    final fadePainter = TextPainter(
      text: TextSpan(style: _style, text: '\u2026'),
      textDirection: _textDirection,
      textScaler: _textScaler,
      locale: _locale,
    )..layout();
    if (didOverflowWidth) {
      final (fadeStart, fadeEnd) = switch (_textDirection) {
        TextDirection.rtl => (fadePainter.width, 0.0),
        TextDirection.ltr => (size.width - fadePainter.width, size.width),
      };
      _overflowShader = ui.Gradient.linear(
        Offset(fadeStart, 0),
        Offset(fadeEnd, 0),
        const <Color>[Color(0xFFFFFFFF), Color(0x00FFFFFF)],
      );
    } else {
      final fadeEnd = size.height;
      final fadeStart = fadeEnd - fadePainter.height / 2;
      _overflowShader = ui.Gradient.linear(
        Offset(0, fadeStart),
        Offset(0, fadeEnd),
        const <Color>[Color(0xFFFFFFFF), Color(0x00FFFFFF)],
      );
    }
    fadePainter.dispose();
  }

  void _replaceApplications(List<_TextMotionApplication> applications) {
    if (attached) {
      _detachAnimations();
    }
    _applications = applications;
    _renderEffects = applications.map(_MotionRenderEffect.forText).toList(growable: false);
    if (hasSize) {
      _updatePaintBounds();
    }
    if (attached) {
      _attachAnimations();
    }
    markNeedsPaint();
  }

  void _attachAnimations() {
    for (final effect in _renderEffects) {
      effect.animation.addListener(_animationListener);
      if (_atlasDeferred) effect.animation.addStatusListener(_atlasStatusListener);
    }
  }

  void _detachAnimations() {
    for (final effect in _renderEffects) {
      effect.animation.removeListener(_animationListener);
      if (_atlasDeferred) effect.animation.removeStatusListener(_atlasStatusListener);
    }
  }

  void _clearTextResources() {
    _setAtlasDeferred(false);
    _discardAtlas();
    _paintedShaderBlur = false;
    _textPainter?.dispose();
    _textPainter = null;
    for (final painter in _glyphPainters) {
      painter.dispose();
    }
    _glyphPainters = const <TextPainter>[];
    _placeholderBoxes = const <ui.TextBox>[];
    _spriteIndexByCharacter = const <int>[];
    _atlasRects = null;
    _atlasTransforms = null;
    _atlasColors = null;
    _glyphSigmas = null;
    _packedBlur = null;
    _characterCenters = null;
    _spriteAnchors = null;
    _atlasDisabled = false;
    _firstOversizedAtlasGlyphCount = null;
    _paintsParagraph = false;
    _overflowShader = null;
  }
}
