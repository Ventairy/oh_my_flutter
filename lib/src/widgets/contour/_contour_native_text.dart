part of 'contour.dart';

// Use native glyph rendering only after its painted coverage is verified.
class _ContourNativeText {
  static RenderParagraph? paragraph(RenderBox? source) {
    var node = source;
    while (node != null) {
      if (node is RenderParagraph) return node;
      final type = node.runtimeType;
      if (!const <Type>{
        RenderSemanticsAnnotations,
        RenderExcludeSemantics,
        RenderConstrainedBox,
        RenderPositionedBox,
        RenderPadding,
        RenderIgnorePointer,
        RenderAbsorbPointer,
        RenderRepaintBoundary,
      }.contains(type)) {
        return null;
      }
      if (node is RenderProxyBox) {
        node = node.child;
      } else if (node is RenderShiftedBox) {
        node = node.child;
      } else {
        return null;
      }
    }
    return null;
  }

  static bool accepts(RenderBox? source) {
    final text = paragraph(source);
    return text != null &&
        text.runtimeType == RenderParagraph &&
        text.registrar == null &&
        (text.strutStyle == null || text.strutStyle.runtimeType == StrutStyle) &&
        text.childCount == 0 &&
        text.overflow != TextOverflow.fade &&
        _plain(text.text);
  }

  static bool _plain(InlineSpan span) {
    if (span.runtimeType != TextSpan) return false;
    final text = span as TextSpan;
    final style = text.style;
    if (style != null && style.runtimeType != TextStyle) return false;
    if (style != null &&
        ((style.color != null && style.color!.a != 1) ||
            style.foreground != null ||
            style.background != null ||
            style.backgroundColor != null ||
            (style.shadows?.isNotEmpty ?? false) ||
            (style.decoration != null && style.decoration != TextDecoration.none))) {
      return false;
    }
    return text.children?.every(_plain) ?? true;
  }

  static Object signature(RenderParagraph source) => (
    source.text,
    source.constraints,
    source.textAlign,
    source.textDirection,
    source.textScaler,
    source.maxLines,
    source.locale,
    source.strutStyle,
    source.textWidthBasis,
    source.textHeightBehavior,
    source.devicePixelRatio,
    source.softWrap,
    source.overflow,
  );

  Object? settings;
  TextPainter? _fill;
  TextPainter? _stroke;
  double? _amount;
  Color? _color;
  int fillPainterCreations = 0;
  int fillLayoutBuilds = 0;
  int fillPaintUpdates = 0;

  bool update(RenderParagraph source, double amount, {Color color = const Color(0xFFFFFFFF)}) {
    final next = signature(source);
    final contentChanged = settings != next;
    final colorChanged = _color != color;
    if (!contentChanged && !colorChanged && _amount == amount) return false;
    if (contentChanged) {
      _fill?.dispose();
      _fill = _painter(source, Paint()..color = color, retainedPaint: true);
      fillPainterCreations++;
      fillLayoutBuilds++;
    } else if (colorChanged) {
      _fill!.text = _ContourNativeTextSpan(
        shapeKey: next,
        source: _span(source.text as TextSpan, Paint()..color = color),
      );
      // The verified shape is unchanged. TextPainter keeps its line geometry
      // for this paint-only span and its layout call returns from that cache.
      _layout(_fill!, source);
      fillPaintUpdates++;
    }
    if (contentChanged) {
      _stroke?.dispose();
      _stroke = null;
    }
    if (amount > 0) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = amount * 2
        ..strokeJoin = StrokeJoin.round;
      if (_stroke != null) {
        _stroke!.text = _ContourNativeTextSpan(shapeKey: next, source: _span(source.text as TextSpan, paint));
        _layout(_stroke!, source);
      } else {
        _stroke?.dispose();
        _stroke = _painter(source, paint, retainedPaint: true);
      }
    }
    settings = next;
    _amount = amount;
    _color = color;
    return true;
  }

  bool clipped(RenderParagraph source) =>
      source.overflow != TextOverflow.visible &&
      (_fill!.didExceedMaxLines || _fill!.width > source.size.width || _fill!.height > source.size.height);

  TextPainter _painter(RenderParagraph source, Paint paint, {bool retainedPaint = false}) =>
      TextPainter(
        text: retainedPaint
            ? _ContourNativeTextSpan(shapeKey: signature(source), source: _span(source.text as TextSpan, paint))
            : _span(source.text as TextSpan, paint),
        textAlign: source.textAlign,
        textDirection: source.textDirection,
        textScaler: source.textScaler,
        maxLines: source.maxLines,
        ellipsis: source.overflow == TextOverflow.ellipsis ? '\u2026' : null,
        locale: source.locale,
        strutStyle: source.strutStyle,
        textWidthBasis: source.textWidthBasis,
        textHeightBehavior: source.textHeightBehavior,
      )..layout(
        minWidth: source.constraints.minWidth,
        maxWidth: source.softWrap || source.overflow == TextOverflow.ellipsis
            ? source.constraints.maxWidth
            : double.infinity,
      );

  void _layout(TextPainter painter, RenderParagraph source) => painter.layout(
    minWidth: source.constraints.minWidth,
    maxWidth: source.softWrap || source.overflow == TextOverflow.ellipsis
        ? source.constraints.maxWidth
        : double.infinity,
  );

  TextSpan _span(TextSpan span, Paint paint) => TextSpan(
    text: span.text,
    locale: span.locale,
    style: (span.style ?? const TextStyle()).copyWith(
      foreground: paint,
      shadows: const [],
      decoration: TextDecoration.none,
    ),
    children: span.children?.map((child) => _span(child as TextSpan, paint)).toList(),
  );

  ui.Picture verificationPicture(
    RenderParagraph source,
    Path shape,
    Rect bounds,
    double ratio,
    int panelHeight,
    Offset origin,
  ) {
    update(source, 1);
    final thin = _painter(
      source,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .01
        ..strokeJoin = StrokeJoin.round,
    );
    final recolored = _painter(source, Paint()..color = const Color(0xFFFF0000));
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final fill = Paint()..color = const Color(0xFFFFFFFF);
    final stroke = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    for (var panel = 0; panel < 5; panel++) {
      canvas
        ..save()
        ..clipRect(
          Rect.fromLTWH(
            0,
            (panel * panelHeight).toDouble(),
            (bounds.width * ratio).ceilToDouble(),
            panelHeight.toDouble(),
          ),
        )
        ..translate(0, (panel * panelHeight).toDouble())
        ..scale(ratio)
        ..translate(-bounds.left, -bounds.top);
      switch (panel) {
        case 0:
          _fill!.paint(canvas, origin);
        case 1:
          paint(canvas, origin);
        case 2:
          thin.paint(canvas, origin);
        case 3:
          canvas
            ..drawPath(shape, fill)
            ..drawPath(shape, stroke);
        case 4:
          recolored.paint(canvas, origin);
      }
      canvas.restore();
    }
    thin.dispose();
    recolored.dispose();
    return recorder.endRecording();
  }

  void paint(Canvas canvas, [Offset origin = Offset.zero]) {
    _fill!.paint(canvas, origin);
    if (_amount != 0) _stroke?.paint(canvas, origin);
  }

  void dispose() {
    _fill?.dispose();
    _stroke?.dispose();
    _fill = null;
    _stroke = null;
    settings = null;
    _amount = null;
    _color = null;
  }
}
