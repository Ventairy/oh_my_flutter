part of 'contour.dart';

class _ContourCompositeBacking {
  Object? _token;
  ContourCompositeResult? _result;
  ContourLayerPictureSnapshot? _snapshot;
  _ContourLayer? _sourceLayer;
  Rect _sourceBounds = Rect.zero;
  Rect captureBounds = Rect.zero;
  int _revision = -1;
  double sourceRatio = 1;
  double _outputRatio = 1;
  WeakReference<RenderView>? _view;
  Matrix4? _restTransform;
  Matrix4? _inverseRest;
  double _restScale = 1;
  bool pending = false;
  bool declined = false;

  bool get ready => _result?.picture != null;
  ui.Picture? get picture => _result?.picture;
  Object? get identity => _token;
  Rect? get bounds {
    final result = _result;
    return result == null
        ? null
        : MatrixUtils.transformRect(
            _inverseRest!,
            Rect.fromLTRB(
              captureBounds.left + result.boundsPx.left / sourceRatio,
              captureBounds.top + result.boundsPx.top / sourceRatio,
              captureBounds.left + result.boundsPx.right / sourceRatio,
              captureBounds.top + result.boundsPx.bottom / sourceRatio,
            ),
          );
  }

  ({ContourLayerSnapshotStamp stamp, Rect bounds})? retainSource() {
    final stamp = _snapshot?.stamp.copy();
    return stamp == null ? null : (stamp: stamp, bounds: _sourceBounds);
  }

  bool current(_RenderContour owner, _RenderContourCapture capture) {
    final layer = _sourceLayer;
    return (pending || ready) &&
        layer != null &&
        _revision == owner._contentRevision &&
        identical(layer, capture.captureLayer) &&
        _sourceBounds == capture.paintBounds &&
        _viewCurrent(owner, capture) &&
        (_snapshot?.isCurrent(root: layer, bounds: captureBounds, pixelRatio: sourceRatio, generation: _revision) ??
            false);
  }

  bool _viewCurrent(_RenderContour owner, _RenderContourCapture capture) {
    final expected = _view?.target;
    if (expected == null ||
        owner._pixelRatio != _outputRatio ||
        expected.configuration.devicePixelRatio != _outputRatio ||
        expected.flutterView.devicePixelRatio != _outputRatio) {
      return false;
    }
    RenderObject? ancestor = capture;
    while (ancestor != null && ancestor is! RenderView) {
      ancestor = ancestor.parent;
    }
    return identical(ancestor, expected);
  }

  void invalidate() {
    _token = null;
    _snapshot?.dispose();
    _snapshot = null;
    _result?.dispose();
    _result = null;
    _sourceLayer = null;
    _view = null;
    _restTransform = null;
    _inverseRest = null;
    pending = false;
    declined = false;
  }

  bool _prepareFrame(_RenderContour owner, _RenderContourCapture capture) {
    RenderObject? ancestor = capture;
    while (ancestor != null && ancestor is! RenderView) {
      ancestor = ancestor.parent;
    }
    if (ancestor is! RenderView) return false;
    final ratio = ancestor.configuration.devicePixelRatio;
    if (!ratio.isFinite || ratio <= 0 || ratio != owner._pixelRatio || ratio != ancestor.flutterView.devicePixelRatio) {
      return false;
    }
    final rest = RestingPaintTransform.toView(capture);
    if (rest == null || !_finiteAffine(rest)) return false;
    final m = rest.storage;
    final xx = m[0] * m[0] + m[1] * m[1];
    final yy = m[4] * m[4] + m[5] * m[5];
    final tolerance = math.max(1, math.max(xx, yy)) * 1e-9;
    if (m[0] * m[5] - m[1] * m[4] <= 1e-9 ||
        (xx - yy).abs() > tolerance ||
        (m[0] * m[4] + m[1] * m[5]).abs() > tolerance) {
      return false;
    }
    final inverse = Matrix4.tryInvert(rest);
    if (inverse == null) return false;
    final initial = capture.getTransformTo(null)..multiply(inverse);
    if (!_finiteAffine(initial)) return false;
    final v = initial.storage;
    final aa = v[0] * v[0] + v[1] * v[1];
    final bb = v[4] * v[4] + v[5] * v[5];
    final cross = v[0] * v[4] + v[1] * v[5];
    final maximumScaleSquared = (aa + bb + math.sqrt((aa - bb) * (aa - bb) + 4 * cross * cross)) / 2;
    if (maximumScaleSquared > 1 + 1e-9) return false;
    final scale = math.sqrt(xx);
    final amount = owner._amount * ratio * scale;
    if (!amount.isFinite || amount < .5 || amount > 128) return false;
    if (owner._shadows.isNotEmpty) {
      final shadow = owner._shadows.single;
      final sigma = shadow.blurSigma * ratio * scale;
      final dx = (m[0] * shadow.offset.dx + m[4] * shadow.offset.dy) * ratio;
      final dy = (m[1] * shadow.offset.dx + m[5] * shadow.offset.dy) * ratio;
      if (!sigma.isFinite || sigma > 128 || !dx.isFinite || !dy.isFinite || dx.abs() > 4096 || dy.abs() > 4096) {
        return false;
      }
    }
    _view = WeakReference(ancestor);
    _outputRatio = ratio;
    _restTransform = rest;
    _inverseRest = inverse;
    _restScale = scale;
    return true;
  }

  bool _finiteAffine(Matrix4 matrix) {
    final m = matrix.storage;
    if (m.any((value) => !value.isFinite)) return false;
    for (final index in const [2, 3, 6, 7, 8, 9, 11, 14]) {
      if (m[index].abs() > 1e-9) return false;
    }
    return (m[10] - 1).abs() <= 1e-9 && (m[15] - 1).abs() <= 1e-9;
  }

  bool _densityChanging(_RenderContour owner, _RenderContourCapture capture) {
    RenderObject? view = capture;
    while (view != null && view is! RenderView) {
      view = view.parent;
    }
    return view is RenderView &&
        (owner._pixelRatio != view.configuration.devicePixelRatio ||
            owner._pixelRatio != view.flutterView.devicePixelRatio);
  }

  Rect? _alignedBounds(_RenderContourCapture capture, double padding) {
    final bounds = MatrixUtils.transformRect(
      _restTransform!,
      capture.paintBounds,
    ).inflate(math.max(padding, 2 / _outputRatio));
    final aligned = Rect.fromLTRB(
      (bounds.left * _outputRatio).floorToDouble() / _outputRatio,
      (bounds.top * _outputRatio).floorToDouble() / _outputRatio,
      (bounds.right * _outputRatio).ceilToDouble() / _outputRatio,
      (bounds.bottom * _outputRatio).ceilToDouble() / _outputRatio,
    );
    return aligned.isFinite && !aligned.isEmpty ? aligned : null;
  }

  void paint(Canvas canvas) {
    canvas
      ..transform(_inverseRest!.storage)
      ..translate(captureBounds.left, captureBounds.top)
      ..scale(1 / sourceRatio)
      ..drawPicture(picture!);
  }

  Future<bool> prepare(
    _RenderContour owner,
    _RenderContourCapture capture, {
    required int lifetime,
    required int revision,
    required Completer<void> cancellation,
  }) async {
    invalidate();
    final token = Object();
    _token = token;
    pending = true;
    final layer = capture.captureLayer;
    final sourceBounds = capture.paintBounds;
    _sourceLayer = layer;
    _sourceBounds = sourceBounds;
    _revision = revision;
    bool validOwner() =>
        identical(_token, token) &&
        owner.attached &&
        owner._lifetime == lifetime &&
        owner._contentRevision == revision &&
        !cancellation.isCompleted &&
        owner._hasDecoration &&
        identical(capture.captureLayer, layer) &&
        capture.paintBounds == sourceBounds &&
        !capture.hasPendingContour;
    try {
      if (layer == null || !layer.supportsRasterization() || sourceBounds.isEmpty || !sourceBounds.isFinite) {
        return false;
      }
      var frameReady = _prepareFrame(owner, capture);
      if (!frameReady && _densityChanging(owner, capture)) {
        // View notifications can cancel a generation before its widget has
        // rebuilt with the new DPR. Let that frame update the owner first.
        await Future.any([SchedulerBinding.instance.endOfFrame, cancellation.future]);
        if (!validOwner()) return false;
        frameReady = _prepareFrame(owner, capture);
      }
      if (!frameReady) {
        declined = true;
        return false;
      }
      var padding = 1 / owner._captureRatio(MatrixUtils.transformRect(_restTransform!, sourceBounds));
      for (var attempt = 0; attempt < 5; attempt++) {
        final sampled = _alignedBounds(capture, padding);
        if (sampled == null) break;
        final ratio = owner._captureRatio(sampled);
        final width = (sampled.width * ratio).ceil();
        final height = (sampled.height * ratio).ceil();
        if (!ratio.isFinite ||
            ratio <= 0 ||
            ratio > 8 ||
            width < 1 ||
            height < 1 ||
            width > 2048 ||
            height > 2048 ||
            width * height > 262144) {
          break;
        }
        final textKey = _ContourNativeTextCache.key(capture, 1, sourceBounds);
        if (textKey != null && textKey != capture._paintedTextKey) {
          // Layout and font notifications can resume a cancelled generation
          // before its replacement paragraph has painted. Never share that old
          // recording under the new paragraph's value key.
          capture.markNeedsPaint();
          await Future.any([SchedulerBinding.instance.endOfFrame, cancellation.future]);
          if (!validOwner()) return false;
          continue;
        }
        _snapshot?.dispose();
        final snapshot = ContourLayerPictureSnapshot.captureChildren(
          root: layer,
          bounds: sampled,
          pixelRatio: ratio,
          generation: revision,
          transform: _restTransform,
        );
        if (snapshot == null) break;
        _snapshot = snapshot;
        captureBounds = sampled;
        sourceRatio = ratio;
        final shadow = owner._shadows.isEmpty ? null : owner._shadows.single;
        final matrix = _restTransform!.storage;
        final amount = owner._amount * _outputRatio * _restScale;
        final color = owner._color.toARGB32();
        final shadowColor = shadow?.color.toARGB32() ?? 0;
        final sigma = (shadow?.blurSigma ?? 0) * _outputRatio * _restScale;
        final dx = (matrix[0] * (shadow?.offset.dx ?? 0) + matrix[4] * (shadow?.offset.dy ?? 0)) * _outputRatio;
        final dy = (matrix[1] * (shadow?.offset.dx ?? 0) + matrix[5] * (shadow?.offset.dy ?? 0)) * _outputRatio;
        // Equal text/layout alone is insufficient: preserve rotation, density,
        // decoration and the exact source position within its capture grid.
        final groupKey = textKey == null
            ? null
            : (
                textKey,
                _view!.target!.flutterView.viewId,
                width,
                height,
                ratio,
                _outputRatio,
                matrix[0],
                matrix[1],
                matrix[4],
                matrix[5],
                matrix[12] - sampled.left,
                matrix[13] - sampled.top,
                amount,
                color,
                shadowColor,
                sigma,
                dx,
                dy,
              );
        Future<ContourCompositeResult?> future;
        try {
          future = _ContourCompositePendingGroup.capture(
            key: groupKey,
            cancelled: cancellation.future,
            create: (cancelled) => ContourCompositeSource.shared.capturePicture(
              snapshot.picture,
              width: width,
              height: height,
              sourceRatio: ratio,
              outputRatio: _outputRatio,
              amountOutputPx: amount,
              contourArgb: color,
              shadowArgb: shadowColor,
              shadowSigmaOutputPx: sigma,
              shadowDxOutputPx: dx,
              shadowDyOutputPx: dy,
              cancelled: cancelled,
            ),
          );
        } finally {
          snapshot.releasePicture();
        }
        final result = await future;
        if (!validOwner()) {
          result?.dispose();
          return false;
        }
        if (!_viewCurrent(owner, capture)) {
          result?.dispose();
          declined = true;
          return false;
        }
        if (!current(owner, capture)) {
          result?.dispose();
          owner
            ..contentChanged()
            ..markNeedsPaint();
          return false;
        }
        if (result == null) break;
        if (result.sourceTouchesBoundary) {
          result.dispose();
          padding *= 4;
          continue;
        }
        _result = result;
        owner
          .._pending = false
          .._nativeActive = false
          .._nativeStatus = 'native-composite'
          .._replaceGeometry(ContourGeometry.declared(Path()..addRect(bounds!)))
          .._syncReadiness()
          ..markNeedsPaint();
        return true;
      }
      if (validOwner()) declined = true;
      return false;
    } finally {
      if (identical(_token, token)) pending = false;
    }
  }
}
