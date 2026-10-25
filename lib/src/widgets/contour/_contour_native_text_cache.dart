part of 'contour.dart';

class _ContourNativeTextCache {
  // Limit both retained geometry and key traversal. Rich text can otherwise
  // retain large strings or make each cache lookup walk an unbounded tree.
  static const _maximumEntries = 64;
  static const int _maximumBytes = 8 * 1024 * 1024;
  static const int _maximumKeyBytes = 64 * 1024;
  static const _maximumSpans = 256;
  static const _maximumDepth = 64;
  static final _entries = <_ContourNativeTextCacheKey, _ContourNativeTextCacheEntry>{};
  static final _pending = <_ContourNativeTextCacheKey, Completer<_ContourNativeTextCacheEntry?>>{};
  static int _clients = 0;
  static int epoch = 0;
  static int estimatedBytes = 0;
  static int pendingEstimatedBytes = 0;

  static void acquire() {
    if (_clients++ == 0) PaintingBinding.instance.systemFonts.addListener(_invalidate);
  }

  static void release() {
    if (--_clients != 0) return;
    PaintingBinding.instance.systemFonts.removeListener(_invalidate);
    _invalidate();
  }

  static void _invalidate() {
    epoch++;
    ContourNativeMaskPictureCache.instance.clear();
    ContourGeometryCache.instance.clear();
    _entries.clear();
    estimatedBytes = 0;
    for (final request in _pending.values) {
      request.complete(null);
    }
    _pending.clear();
    pendingEstimatedBytes = 0;
  }

  static ({_ContourNativeTextCacheEntry? value, Future<_ContourNativeTextCacheEntry?>? wait, bool owner}) obtain(
    _ContourNativeTextCacheKey key,
  ) {
    final entry = _entries.remove(key);
    if (entry != null) {
      _entries[key] = entry;
      return (value: entry, wait: null, owner: false);
    }
    final pending = _pending[key];
    if (pending != null) return (value: null, wait: pending.future, owner: false);
    if (key.estimatedBytes > _maximumKeyBytes ||
        _pending.length >= _maximumEntries ||
        pendingEstimatedBytes + key.estimatedBytes > _maximumBytes) {
      return (value: null, wait: null, owner: false);
    }
    _pending[key] = Completer<_ContourNativeTextCacheEntry?>();
    pendingEstimatedBytes += key.estimatedBytes;
    return (value: null, wait: null, owner: true);
  }

  static _ContourNativeTextCacheEntry? peek(_ContourNativeTextCacheKey key) {
    final entry = _entries.remove(key);
    if (entry != null) _entries[key] = entry;
    return entry;
  }

  static void replace(
    _ContourNativeTextCacheKey key,
    _ContourNativeTextCacheEntry expected,
    _ContourNativeTextCacheEntry next,
  ) {
    if (!identical(_entries[key], expected)) return;
    _entries[key] = next;
  }

  static void complete(_ContourNativeTextCacheKey key, _ContourNativeTextCacheEntry? entry) {
    final request = _pending.remove(key);
    // Invalidated requests must never repopulate an older font epoch.
    if (request == null) return;
    pendingEstimatedBytes -= key.estimatedBytes;
    if (entry != null && key.estimatedBytes + entry.estimatedBytes <= _maximumBytes) {
      final previous = _entries.remove(key);
      if (previous != null) estimatedBytes -= key.estimatedBytes + previous.estimatedBytes;
      _entries[key] = entry;
      estimatedBytes += key.estimatedBytes + entry.estimatedBytes;
      while (_entries.length > _maximumEntries || estimatedBytes > _maximumBytes) {
        final oldest = _entries.keys.first;
        final removed = _entries.remove(oldest)!;
        estimatedBytes -= oldest.estimatedBytes + removed.estimatedBytes;
      }
    }
    request.complete(entry);
  }

  static _ContourNativeTextCacheKey? key(_RenderContourCapture capture, double pixelRatio, Rect bounds) {
    final source = _ContourNativeText.paragraph(capture.child);
    if (source == null ||
        source.runtimeType != RenderParagraph ||
        source.registrar != null ||
        (source.locale != null && source.locale.runtimeType != Locale) ||
        (source.strutStyle != null && source.strutStyle.runtimeType != StrutStyle)) {
      return null;
    }
    final scaler = source.textScaler;
    final Object scalerKey;
    if (scaler is SystemTextScaler) {
      // This final SDK type defines equivalent scaling by its snapshot
      // preference. Keep that opaque value, never its live dispatcher, and do
      // not conflate nonlinear system scaling with a linear scale(1) sample.
      scalerKey = (SystemTextScaler, scaler.textScaleFactor);
    } else if (scaler.runtimeType == TextScaler.noScaling.runtimeType) {
      scalerKey = (scaler.runtimeType, scaler.scale(1));
    } else {
      return null;
    }
    // Bound traversal before recursively checking native eligibility. Rejected
    // keys still allow an owner to verify and paint its own native glyph mask.
    final text = _span(source.text, remainingBytes: _maximumKeyBytes - 512);
    if (text == null || !_ContourNativeText.accepts(capture.child)) return null;
    final strut = _strut(source.strutStyle, _maximumKeyBytes - 512 - text.bytes);
    if (strut == null) return null;
    final bytes = 512 + text.bytes + strut.bytes + _localeBytes(source.locale);
    if (bytes > _maximumKeyBytes) return null;
    final translation = source.getTransformTo(capture).getTranslation();
    return _ContourNativeTextCacheKey(
      (
        epoch,
        text.span,
        BoxConstraints(
          minWidth: source.constraints.minWidth,
          maxWidth: source.constraints.maxWidth,
          minHeight: source.constraints.minHeight,
          maxHeight: source.constraints.maxHeight,
        ),
        // Debug-mode Size values can carry their owning render box. Snapshot
        // scalars so cached painting values never retain a source widget tree.
        Size(source.size.width, source.size.height),
        Size(capture.size.width, capture.size.height),
        Rect.fromLTRB(bounds.left, bounds.top, bounds.right, bounds.bottom),
        pixelRatio,
        Offset(translation.x, translation.y),
        source.textAlign,
        source.textDirection,
        scalerKey,
        source.maxLines,
        _locale(source.locale),
        strut.style,
        source.textWidthBasis,
        source.textHeightBehavior == null
            ? null
            : TextHeightBehavior(
                applyHeightToFirstAscent: source.textHeightBehavior!.applyHeightToFirstAscent,
                applyHeightToLastDescent: source.textHeightBehavior!.applyHeightToLastDescent,
                leadingDistribution: source.textHeightBehavior!.leadingDistribution,
              ),
        source.devicePixelRatio,
        source.softWrap,
        source.overflow,
      ),
      bytes,
    );
  }

  static ({TextSpan span, int bytes, int spans})? _span(
    InlineSpan source, {
    required int remainingBytes,
    int remainingSpans = _maximumSpans,
    int depth = 1,
  }) {
    if (source.runtimeType != TextSpan || depth > _maximumDepth || remainingSpans < 1) return null;
    final span = source as TextSpan;
    if (span.locale != null && span.locale.runtimeType != Locale) return null;
    final sourceChildren = span.children ?? const <InlineSpan>[];
    if (sourceChildren.length >= remainingSpans) return null;
    var bytes = 160 + _stringBytes(span.text) + _localeBytes(span.locale) + sourceChildren.length * 8;
    if (bytes > remainingBytes) return null;
    final style = _style(span.style, remainingBytes - bytes);
    if (style == null) return null;
    bytes += style.bytes;
    var spans = 1;
    final children = <InlineSpan>[];
    for (final child in sourceChildren) {
      final snapshot = _span(
        child,
        remainingBytes: remainingBytes - bytes,
        remainingSpans: remainingSpans - spans,
        depth: depth + 1,
      );
      if (snapshot == null) return null;
      bytes += snapshot.bytes;
      spans += snapshot.spans;
      children.add(snapshot.span);
    }
    // Keep painting values, never callbacks, recognizers, or semantic objects.
    return (
      span: TextSpan(
        text: span.text,
        style: style.style,
        locale: _locale(span.locale),
        children: List<InlineSpan>.unmodifiable(children),
      ),
      bytes: bytes,
      spans: spans,
    );
  }

  static ({TextStyle? style, int bytes})? _style(TextStyle? style, int remainingBytes) {
    if (style == null) return (style: null, bytes: 0);
    if (style.runtimeType != TextStyle ||
        !_supportsColor(style.color) ||
        !_supportsColor(style.decorationColor) ||
        (style.locale != null && style.locale.runtimeType != Locale) ||
        style.foreground != null ||
        style.background != null ||
        style.backgroundColor != null ||
        (style.shadows?.isNotEmpty ?? false)) {
      return null;
    }
    var bytes = 512 + _stringBytes(style.fontFamily) + _localeBytes(style.locale);
    if (bytes > remainingBytes) return null;
    final fallback = _families(style.fontFamilyFallback, remainingBytes - bytes);
    if (fallback == null) return null;
    bytes += fallback.bytes;
    final features = style.fontFeatures;
    final variations = style.fontVariations;
    if ((features?.length ?? 0) > _maximumSpans || (variations?.length ?? 0) > _maximumSpans) return null;
    bytes += (features?.length ?? 0) * 96 + (variations?.length ?? 0) * 96;
    if (bytes > remainingBytes) return null;
    // These are all TextStyle painting/layout fields. Debug labels are omitted
    // so a diagnostic string cannot keep an arbitrarily large object alive.
    return (
      style: TextStyle(
        inherit: style.inherit,
        color: _color(style.color),
        fontSize: style.fontSize,
        fontWeight: style.fontWeight == null ? null : FontWeight(style.fontWeight!.value),
        fontStyle: style.fontStyle,
        letterSpacing: style.letterSpacing,
        wordSpacing: style.wordSpacing,
        textBaseline: style.textBaseline,
        height: style.height,
        leadingDistribution: style.leadingDistribution,
        locale: _locale(style.locale),
        fontFeatures: features == null
            ? null
            : List<ui.FontFeature>.unmodifiable(
                features.map((feature) => ui.FontFeature(feature.feature, feature.value)),
              ),
        fontVariations: variations == null
            ? null
            : List<ui.FontVariation>.unmodifiable(
                variations.map((variation) => ui.FontVariation(variation.axis, variation.value)),
              ),
        decoration: style.decoration == null ? null : TextDecoration.none,
        decorationColor: _color(style.decorationColor),
        decorationStyle: style.decorationStyle,
        decorationThickness: style.decorationThickness,
        // These getters already include any package prefix.
        fontFamily: style.fontFamily,
        fontFamilyFallback: fallback.families,
        overflow: style.overflow,
      ),
      bytes: bytes,
    );
  }

  static ({StrutStyle? style, int bytes})? _strut(StrutStyle? style, int remainingBytes) {
    if (style == null) return (style: null, bytes: 0);
    var bytes = 256 + _stringBytes(style.fontFamily);
    if (bytes > remainingBytes) return null;
    final fallback = _families(style.fontFamilyFallback, remainingBytes - bytes);
    if (fallback == null) return null;
    bytes += fallback.bytes;
    return (
      style: StrutStyle(
        fontFamily: style.fontFamily,
        fontFamilyFallback: fallback.families,
        fontSize: style.fontSize,
        height: style.height,
        leadingDistribution: style.leadingDistribution,
        leading: style.leading,
        fontWeight: style.fontWeight == null ? null : FontWeight(style.fontWeight!.value),
        fontStyle: style.fontStyle,
        forceStrutHeight: style.forceStrutHeight,
      ),
      bytes: bytes,
    );
  }

  static ({List<String>? families, int bytes})? _families(List<String>? families, int remainingBytes) {
    if (families == null) return (families: null, bytes: 0);
    if (families.length > _maximumSpans) return null;
    var bytes = 32 + families.length * 8;
    if (bytes > remainingBytes) return null;
    for (final family in families) {
      bytes += _stringBytes(family);
      if (bytes > remainingBytes) return null;
    }
    return (families: List<String>.unmodifiable(families), bytes: bytes);
  }

  static int _stringBytes(String? value) => value == null ? 0 : 32 + value.length * 2;

  static int _localeBytes(Locale? locale) => locale == null
      ? 0
      : 64 + _stringBytes(locale.languageCode) + _stringBytes(locale.scriptCode) + _stringBytes(locale.countryCode);

  static Locale? _locale(Locale? locale) => locale == null
      ? null
      : Locale.fromSubtags(
          languageCode: locale.languageCode,
          scriptCode: locale.scriptCode,
          countryCode: locale.countryCode,
        );

  // Unknown subclasses can serialize a different alpha than their channels or
  // retain application state. Keep them on per-owner verification instead.
  static bool _supportsColor(Color? color) =>
      color == null ||
      const <Type>{Color, ColorSwatch<int>, MaterialColor, MaterialAccentColor}.contains(color.runtimeType);

  static Color? _color(Color? color) => color == null
      ? null
      : Color.from(alpha: color.a, red: color.r, green: color.g, blue: color.b, colorSpace: color.colorSpace);
}
