part of '../motion.dart';

/// Paints every text effect through one cached atlas draw operation.
class _RenderOptimizedTextMotion extends RenderBox with RelayoutWhenSystemFontsChangeMixin {
  _RenderOptimizedTextMotion({
    required this._graphemes,
    required this._applications,
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
    required this._baseline,
    required this._devicePixelRatio,
    required this._attributedLabel,
    required this._semanticsIdentifier,
  }) : _renderEffects = _applications.map(_MotionRenderEffect.forText).toList(growable: false);

  static const int _maximumAtlasDimension = 2048;
  static const int _maximumAtlasPixels = 1024 * 1024;

  final Paint _atlasPaint = Paint()..filterQuality = FilterQuality.low;
  final Paint _fallbackOpacityPaint = Paint();
  final Paint _overflowLayerPaint = Paint();
  final Paint _overflowShaderPaint = Paint()..blendMode = BlendMode.modulate;
  final MotionEffectTransform _effectTransform = MotionEffectTransform._();
  late final VoidCallback _animationListener = markNeedsPaint;

  List<String> _graphemes;
  List<_TextMotionApplication> _applications;
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
  bool _needsClipping = false;
  bool _paintsParagraph = false;
  ui.Shader? _overflowShader;
  double _computedOpacity = 1;
  double _computedScale = 1;
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

    var maximumScale = 1.0;
    var horizontalMotion = 0.0;
    var verticalMotion = 0.0;
    for (final effect in _renderEffects) {
      final bounds = effect.bounds;
      horizontalMotion += bounds.maximumAbsoluteTranslationX;
      verticalMotion += bounds.maximumAbsoluteTranslationY;
      maximumScale *= math.max(1, bounds.maximumAbsoluteScale);
    }
    final horizontalOutset = horizontalMotion * maximumScale + size.width * (maximumScale - 1) / 2;
    final verticalOutset = verticalMotion * maximumScale + size.height * (maximumScale - 1) / 2;
    _cachedPaintBounds = Rect.fromLTRB(
      -horizontalOutset,
      -verticalOutset,
      size.width + horizontalOutset,
      size.height + verticalOutset,
    );
  }

  void updateConfiguration({
    required List<String> graphemes,
    required List<_TextMotionApplication> applications,
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
      _baseline = baseline;
      _devicePixelRatio = devicePixelRatio;
      _clearTextResources();
      markNeedsLayout();
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
    _preparePaintBuffers();
    _configureOverflow(textSize, painter.didExceedMaxLines);
    _updatePaintBounds();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final painter = _textPainter;
    if (painter == null) {
      return;
    }

    final canvas = context.canvas;
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
      _paintGlyphsWithoutAtlas(canvas, offset);
    } else {
      _paintAtlas(canvas, atlas, offset);
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
          translationX: _computedTranslationX,
          translationY: _computedTranslationY,
        );
      },
      growable: false,
    );
    properties
      ..add(IntProperty('animatedCharacterCount', states.length))
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
    )..setPlaceholderDimensions(dimensions);
    _textPainter = painter;
    _glyphPainters = glyphPainters;
    _spriteIndexByCharacter = spriteIndexByCharacter;
    _buildAtlas();
    return painter;
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
    );
  }

  void _buildAtlas() {
    if (_atlasDisabled || _glyphPainters.isEmpty) {
      return;
    }

    final padding = _atlasPadding;
    final paddingPixels = (padding * _devicePixelRatio).ceil();
    final sprites = <_TextMotionSprite>[];
    var x = 0;
    var y = 0;
    var rowHeight = 0;
    var atlasWidth = 0;
    for (final painter in _glyphPainters) {
      final glyphWidth = (painter.width * _devicePixelRatio).ceil();
      final glyphHeight = (painter.height * _devicePixelRatio).ceil();
      final spriteWidth = math.max(1, glyphWidth + paddingPixels * 2);
      final spriteHeight = math.max(1, glyphHeight + paddingPixels * 2);
      if (spriteWidth > _maximumAtlasDimension || spriteHeight > _maximumAtlasDimension) {
        _atlasDisabled = true;
        return;
      }
      if (x > 0 && x + spriteWidth > _maximumAtlasDimension) {
        x = 0;
        y += rowHeight;
        rowHeight = 0;
      }
      if (y + spriteHeight > _maximumAtlasDimension) {
        _atlasDisabled = true;
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
      _atlasDisabled = true;
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_devicePixelRatio, _devicePixelRatio);
    for (var index = 0; index < _glyphPainters.length; index += 1) {
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
    _atlas = picture.toImageSync(atlasWidth, atlasHeight);
    picture.dispose();
    _sprites = sprites;
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

  void _paintAtlas(Canvas canvas, ui.Image atlas, Offset offset) {
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
    _prepareMotionFrame();
    for (var index = 0; index < paintCount; index += 1) {
      _computeMotionState();
      final bufferIndex = index * 4;
      final centerIndex = index * 2;
      final rasterScale = _computedScale * inverseDevicePixelRatio;
      transforms[bufferIndex] = rasterScale;
      transforms[bufferIndex + 2] =
          offsetX + centers[centerIndex] + _computedTranslationX - rasterScale * anchors[centerIndex];
      transforms[bufferIndex + 3] =
          offsetY + centers[centerIndex + 1] + _computedTranslationY - rasterScale * anchors[centerIndex + 1];
      final alpha = _computedOpacity >= 1 ? 255 : (_computedOpacity.clamp(0.0, 1.0) * 255).round();
      colors[index] = alpha << 24;
      usesOpacity = usesOpacity || alpha < 255;
    }

    final atlasColors = usesOpacity ? colors : null;
    try {
      canvas.drawRawAtlas(
        atlas,
        transforms,
        rects,
        atlasColors,
        atlasColors == null ? null : BlendMode.srcIn,
        null,
        _atlasPaint,
      );
    } on ui.PictureRasterizationException {
      atlas.dispose();
      _atlas = null;
      _atlasDisabled = true;
      _paintGlyphsWithoutAtlas(canvas, offset);
    }
  }

  void _paintGlyphsWithoutAtlas(Canvas canvas, Offset offset) {
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
      canvas
        ..save()
        ..translate(
          offsetX + centers[centerIndex] + _computedTranslationX,
          offsetY + centers[centerIndex + 1] + _computedTranslationY,
        )
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
    }
  }

  void _computeMotionState() {
    _effectTransform._reset();
    for (var effectIndex = 0; effectIndex < _renderEffects.length; effectIndex += 1) {
      final effect = _renderEffects[effectIndex];
      effect.effect.apply(effect.nextProgress(), _effectTransform);
    }
    _computedOpacity = _effectTransform._opacity;
    _computedScale = _effectTransform._scale;
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
    }
  }

  void _detachAnimations() {
    for (final effect in _renderEffects) {
      effect.animation.removeListener(_animationListener);
    }
  }

  void _clearTextResources() {
    _textPainter?.dispose();
    _textPainter = null;
    for (final painter in _glyphPainters) {
      painter.dispose();
    }
    _glyphPainters = const <TextPainter>[];
    _placeholderBoxes = const <ui.TextBox>[];
    _spriteIndexByCharacter = const <int>[];
    _sprites = const <_TextMotionSprite>[];
    _atlas?.dispose();
    _atlas = null;
    _atlasRects = null;
    _atlasTransforms = null;
    _atlasColors = null;
    _characterCenters = null;
    _spriteAnchors = null;
    _atlasDisabled = false;
    _paintsParagraph = false;
    _overflowShader = null;
  }
}
