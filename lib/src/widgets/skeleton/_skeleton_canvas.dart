part of 'skeleton.dart';

class _SkeletonCanvas implements Canvas {
  _SkeletonCanvas({
    required this._parent,
    required this._commands,
    required this._paintState,
    required this._radius,
  });

  final Canvas _parent;
  final _SkeletonBoneCommands _commands;
  final _SkeletonPaintState _paintState;
  final Radius _radius;

  void _recordFallbackBone() {
    if (!_paintState.isPaintingLeaf || _paintState.leafFallbackRecorded) {
      return;
    }
    _paintState.leafFallbackRecorded = true;
    _commands.addBone(
      _SkeletonDrawRRectCommand(
        RRect.fromRectAndRadius(_paintState.leafBounds, _radius),
      ),
    );
  }

  void _recordLeafBone(_SkeletonBoneCommand command) {
    _paintState.leafFallbackRecorded = true;
    _commands.addBone(command);
  }

  void recordBoundsBone(Rect bounds) {
    _commands.addBone(
      _SkeletonDrawRRectCommand(
        RRect.fromRectAndRadius(bounds, _radius),
      ),
    );
  }

  void recordLeafFallbackBone() => _recordFallbackBone();

  @override
  void drawRect(Rect rect, Paint paint) {
    if (_paintState.isPaintingLeaf) {
      _recordLeafBone(
        _SkeletonDrawRRectCommand(
          RRect.fromRectAndRadius(rect, _radius),
        ),
      );
    } else {
      _parent.drawRect(rect, paint);
    }
  }

  @override
  void drawRRect(RRect rrect, Paint paint) {
    if (_paintState.isPaintingLeaf) {
      _recordLeafBone(
        _SkeletonDrawRRectCommand(
          RRect.fromRectAndRadius(rrect.outerRect, _radius),
        ),
      );
    } else {
      _parent.drawRRect(rrect, paint);
    }
  }

  @override
  void drawDRRect(RRect outer, RRect inner, Paint paint) {
    if (_paintState.isPaintingLeaf) {
      _recordLeafBone(
        _SkeletonDrawDRRectCommand(
          RRect.fromRectAndRadius(outer.outerRect, _radius),
          RRect.fromRectAndRadius(inner.outerRect, _radius),
        ),
      );
    } else {
      _parent.drawDRRect(outer, inner, paint);
    }
  }

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    if (_paintState.isPaintingLeaf) {
      _recordLeafBone(_SkeletonDrawCircleCommand(c, radius));
    } else {
      _parent.drawCircle(c, radius, paint);
    }
  }

  @override
  void drawOval(Rect rect, Paint paint) {
    if (_paintState.isPaintingLeaf) {
      _recordLeafBone(_SkeletonDrawOvalCommand(rect));
    } else {
      _parent.drawOval(rect, paint);
    }
  }

  @override
  void drawPath(Path path, Paint paint) {
    if (_paintState.isPaintingLeaf) {
      if (path.getBounds().isEmpty) {
        _recordFallbackBone();
      } else {
        _recordLeafBone(_SkeletonDrawPathCommand(path));
      }
    } else {
      _parent.drawPath(path, paint);
    }
  }

  @override
  void drawParagraph(Paragraph paragraph, Offset offset) {
    if (!_paintState.isPaintingLeaf) {
      _parent.drawParagraph(paragraph, offset);
      return;
    }

    if (paragraph.height <= 0) return;

    var lineStart = 0;
    for (var lineNumber = 0; lineNumber < paragraph.numberOfLines; lineNumber += 1) {
      final lineRange = paragraph.getLineBoundary(TextPosition(offset: lineStart));
      Rect? lineBounds;
      for (final box in paragraph.getBoxesForRange(
        lineRange.start,
        lineRange.end,
        boxHeightStyle: ui.BoxHeightStyle.tight,
        boxWidthStyle: ui.BoxWidthStyle.tight,
      )) {
        final boxBounds = box.toRect().shift(offset);
        lineBounds = lineBounds?.expandToInclude(boxBounds) ?? boxBounds;
      }

      var nextLineStart = lineRange.end;
      while (paragraph.getLineNumberAt(nextLineStart) == lineNumber) {
        nextLineStart += 1;
      }
      lineStart = nextLineStart;

      if (lineBounds == null || lineBounds.isEmpty) continue;
      _recordLeafBone(
        _SkeletonDrawRRectCommand(RRect.fromRectAndRadius(lineBounds, _radius)),
      );
    }
  }

  @override
  void drawImage(ui.Image image, Offset offset, Paint paint) {
    if (_paintState.isPaintingLeaf) {
      final rect =
          offset &
          Size(
            image.width.toDouble(),
            image.height.toDouble(),
          );
      _recordLeafBone(
        _SkeletonDrawRRectCommand(RRect.fromRectAndRadius(rect, _radius)),
      );
    } else {
      _parent.drawImage(image, offset, paint);
    }
  }

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) {
    if (_paintState.isPaintingLeaf) {
      _recordLeafBone(
        _SkeletonDrawRRectCommand(RRect.fromRectAndRadius(dst, _radius)),
      );
    } else {
      _parent.drawImageRect(image, src, dst, paint);
    }
  }

  @override
  void drawImageNine(ui.Image image, Rect center, Rect dst, Paint paint) {
    if (_paintState.isPaintingLeaf) {
      _recordLeafBone(
        _SkeletonDrawRRectCommand(RRect.fromRectAndRadius(dst, _radius)),
      );
    } else {
      _parent.drawImageNine(image, center, dst, paint);
    }
  }

  @override
  void drawColor(Color color, BlendMode blendMode) {
    if (_paintState.isPaintingLeaf) {
      _recordFallbackBone();
    } else {
      _parent.drawColor(color, blendMode);
    }
  }

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    if (_paintState.isPaintingLeaf) {
      _recordFallbackBone();
    } else {
      _parent.drawLine(p1, p2, paint);
    }
  }

  @override
  void drawPaint(Paint paint) {
    if (_paintState.isPaintingLeaf) {
      _recordFallbackBone();
    } else {
      _parent.drawPaint(paint);
    }
  }

  @override
  void drawPoints(ui.PointMode pointMode, List<Offset> points, Paint paint) {
    if (_paintState.isPaintingLeaf) {
      _recordFallbackBone();
    } else {
      _parent.drawPoints(pointMode, points, paint);
    }
  }

  @override
  void drawRawPoints(ui.PointMode pointMode, Float32List points, Paint paint) {
    if (_paintState.isPaintingLeaf) {
      _recordFallbackBone();
    } else {
      _parent.drawRawPoints(pointMode, points, paint);
    }
  }

  @override
  void drawShadow(
    Path path,
    Color color,
    double elevation,
    bool transparentOccluder,
  ) {
    if (!_paintState.isPaintingLeaf) {
      _parent.drawShadow(path, color, elevation, transparentOccluder);
    }
  }

  @override
  void drawVertices(ui.Vertices vertices, ui.BlendMode blendMode, Paint paint) {
    if (_paintState.isPaintingLeaf) {
      _recordFallbackBone();
    } else {
      _parent.drawVertices(vertices, blendMode, paint);
    }
  }

  @override
  void drawAtlas(
    ui.Image atlas,
    List<RSTransform> transforms,
    List<Rect> rects,
    List<Color>? colors,
    ui.BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) {
    if (_paintState.isPaintingLeaf) {
      _recordFallbackBone();
    } else {
      _parent.drawAtlas(
        atlas,
        transforms,
        rects,
        colors,
        blendMode,
        cullRect,
        paint,
      );
    }
  }

  @override
  void drawRawAtlas(
    ui.Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    ui.BlendMode? blendMode,
    Rect? cullRect,
    Paint paint,
  ) {
    if (_paintState.isPaintingLeaf) {
      _recordFallbackBone();
    } else {
      _parent.drawRawAtlas(
        atlas,
        rstTransforms,
        rects,
        colors,
        blendMode,
        cullRect,
        paint,
      );
    }
  }

  @override
  void drawPicture(ui.Picture picture) {
    if (_paintState.isPaintingLeaf) {
      _recordFallbackBone();
    } else {
      _parent.drawPicture(picture);
    }
  }

  @override
  void clipRect(
    Rect rect, {
    ClipOp clipOp = ClipOp.intersect,
    bool doAntiAlias = true,
  }) {
    _parent.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
    _commands.add(
      _SkeletonClipRectCommand(
        rect: rect,
        clipOp: clipOp,
        doAntiAlias: doAntiAlias,
      ),
    );
  }

  @override
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) {
    _parent.clipRRect(rrect, doAntiAlias: doAntiAlias);
    _commands.add(
      _SkeletonClipRRectCommand(
        rrect: rrect,
        doAntiAlias: doAntiAlias,
      ),
    );
  }

  @override
  void clipPath(Path path, {bool doAntiAlias = true}) {
    _parent.clipPath(path, doAntiAlias: doAntiAlias);
    _commands.add(
      _SkeletonClipPathCommand(path: path, doAntiAlias: doAntiAlias),
    );
  }

  @override
  void clipRSuperellipse(
    ui.RSuperellipse rsuperellipse, {
    bool doAntiAlias = true,
  }) {
    _parent.clipRSuperellipse(rsuperellipse, doAntiAlias: doAntiAlias);
    _commands.add(
      _SkeletonClipRSuperellipseCommand(
        rsuperellipse: rsuperellipse,
        doAntiAlias: doAntiAlias,
      ),
    );
  }

  @override
  void drawArc(
    Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    Paint paint,
  ) {
    if (_paintState.isPaintingLeaf) {
      _recordFallbackBone();
    } else {
      _parent.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
    }
  }

  @override
  void drawRSuperellipse(ui.RSuperellipse rsuperellipse, Paint paint) {
    if (_paintState.isPaintingLeaf) {
      _recordFallbackBone();
    } else {
      _parent.drawRSuperellipse(rsuperellipse, paint);
    }
  }

  @override
  Rect getDestinationClipBounds() => _parent.getDestinationClipBounds();

  @override
  Rect getLocalClipBounds() => _parent.getLocalClipBounds();

  @override
  void save() {
    _parent.save();
    _commands.add(const _SkeletonSaveCommand());
  }

  @override
  void saveLayer(Rect? bounds, Paint paint) {
    _parent.saveLayer(bounds, paint);
    // Bone colors replace the source effect. A plain save keeps geometry and
    // clipping without allocating another offscreen render target per frame.
    _commands.add(const _SkeletonSaveCommand());
  }

  @override
  void restore() {
    _parent.restore();
    _commands.add(const _SkeletonRestoreCommand());
  }

  @override
  int getSaveCount() => _parent.getSaveCount();

  @override
  void translate(double dx, double dy) {
    _parent.translate(dx, dy);
    _commands.add(_SkeletonTranslateCommand(dx, dy));
  }

  @override
  void scale(double sx, [double? sy]) {
    _parent.scale(sx, sy);
    _commands.add(_SkeletonScaleCommand(sx, sy));
  }

  @override
  void rotate(double radians) {
    _parent.rotate(radians);
    _commands.add(_SkeletonRotateCommand(radians));
  }

  @override
  void skew(double sx, double sy) {
    _parent.skew(sx, sy);
    _commands.add(_SkeletonSkewCommand(sx, sy));
  }

  @override
  void transform(Float64List matrix4) {
    _parent.transform(matrix4);
    _commands.add(_SkeletonTransformCommand(matrix4));
  }

  @override
  Float64List getTransform() => _parent.getTransform();

  @override
  void restoreToCount(int count) {
    _parent.restoreToCount(count);
    _commands.add(_SkeletonRestoreToCountCommand(count));
  }
}
