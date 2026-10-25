part of 'contour.dart';

class _RenderContour extends RenderProxyBox {
  new({
    required Color color,
    required double amount,
    required List<Shadow> shadows,
    required double pixelRatio,
    required bool deferPrewarm,
    ContourController? controller,
    bool prepareWhenHidden = false,
    Widget? source,
  }) : this._(color, amount, List.of(shadows), pixelRatio, deferPrewarm, controller, prepareWhenHidden, source);

  new _(
    this._color,
    this._amount,
    this._shadows,
    this._pixelRatio,
    this._deferPrewarm,
    this._controller,
    this._prepareWhenHidden,
    this._sourceWidget,
  ) {
    _configurePaints();
    assert(() {
      final capability = ContourBoxGaussianShadowTestHarness._installed;
      if (capability != null) {
        _boxGaussianShadow = _ContourBoxGaussianShadow(supported: capability._supported);
      }
      return true;
    }(), 'An isolated mesh capability is installed only in debug rendering.');
  }

  static const int _maximumPixels = 3 * 1024 * 1024;
  static final _nativeTracePolicy = ContourNativeTracePolicy();
  static const int _maximumVerificationPixels = 5 * 512 * 1024;
  Color _color;
  double _amount;
  List<Shadow> _shadows;
  double _pixelRatio;
  bool _deferPrewarm;
  final _compositeBacking = _ContourCompositeBacking();
  WeakReference<_RenderContour>? _viewMetricsRegistration;
  ({ContourLayerSnapshotStamp stamp, Rect bounds})? _compositeStyleSource;

  bool get _preferNativeComposite {
    if (_compositeStyleSource != null ||
        _compositeBacking.declined ||
        !ContourCompositeSource.shared.available ||
        _shadows.length > 1 ||
        !_pixelRatio.isFinite ||
        _pixelRatio <= 0 ||
        _pixelRatio > 8 ||
        !_amount.isFinite ||
        _amount < 0 ||
        _amount == 0 ||
        _amount * _pixelRatio > 128 ||
        !_supportsCompositeColor(_color)) {
      return false;
    }
    for (final shadow in _shadows) {
      if (!_supportsCompositeColor(shadow.color) ||
          !shadow.blurRadius.isFinite ||
          shadow.blurRadius < 0 ||
          !(shadow.blurSigma * _pixelRatio).isFinite ||
          shadow.blurSigma * _pixelRatio > 128 ||
          !(shadow.offset.dx * _pixelRatio).isFinite ||
          (shadow.offset.dx * _pixelRatio).abs() > 4096 ||
          !(shadow.offset.dy * _pixelRatio).isFinite ||
          (shadow.offset.dy * _pixelRatio).abs() > 4096) {
        return false;
      }
    }
    return true;
  }

  bool _supportsCompositeColor(Color color) =>
      const <Type>{Color, ColorSwatch<int>, MaterialColor, MaterialAccentColor}.contains(color.runtimeType) &&
      (color.colorSpace == ui.ColorSpace.sRGB || color.colorSpace == ui.ColorSpace.extendedSRGB) &&
      color.a.isFinite &&
      color.a >= 0 &&
      color.a <= 1 &&
      color.r.isFinite &&
      color.r >= 0 &&
      color.r <= 1 &&
      color.g.isFinite &&
      color.g >= 0 &&
      color.g <= 1 &&
      color.b.isFinite &&
      color.b >= 0 &&
      color.b <= 1;

  ContourController? _controller;
  bool _prepareWhenHidden;
  Widget? _sourceWidget;
  bool _preparationRequested = false;
  bool _preparingSource = false;
  bool _reportedReady = false;
  bool _processorAcquired = false;
  bool _proofRunning = false;
  final Paint _fillPaint = Paint()..color = const Color(0xFFFFFFFF);
  final Paint _strokePaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  final Paint _colorPaint = Paint();
  final _decorationLayer = LayerHandle<_ContourPictureDecorationLayer>();
  late final _shadowCache = _ContourShadowCache(markNeedsPaint);
  late final _shadowAtlas = _ContourShadowAtlas(markNeedsPaint);
  bool _atlasActivated = false;
  int _amountChanges = 0;
  int _amountChangesStartedUs = 0;
  int _lastAmountChangeUs = 0;
  List<Paint> _shadowPaints = [];
  List<Paint?>? _knownBoxShadowPaints;
  int _boxGaussianNativePaintCount = 0;
  late var _boxGaussianShadow = _ContourBoxGaussianShadow();
  final _nativeText = _ContourNativeText();
  bool _nativeActive = false;
  bool _hasPresented = false;
  bool _initialFallback = false;
  _ContourNativeTextCacheKey? _compositionCacheKey;
  Object? _proofToken;
  ContourWorkBudgetRequest? _proofRequest;
  Completer<void>? _proofCancellation;
  Completer<_ContourNativeTextCacheEntry?>? _proofCompletion;
  Future<_ContourNativeTextCacheEntry?>? _awaitedProof;
  VoidCallback? _proofPresentation;
  Object? _proofSettings;
  bool _nativeProofPending = false;
  bool _proofMayStart = false;
  bool _proofWakeScheduled = false;
  int _firstPresentationFrameNumber = -1;
  bool? _firstPresentationHasContour;
  int _lastMainCompositionFrameNumber = -1;
  bool _lastMainCompositionHasContent = false;
  bool _lastMainCompositionHasContour = false;
  Offset _nativeOffset = Offset.zero;
  bool _nativeNeedsShadow = false;
  Object? _nativeAcceptedSettings;
  Object? _nativeMaskSourceId;
  int _nativeMaskSourceBytes = 0;
  int? _nativeVerificationRevision;
  int _nativeVerificationCount = 0;
  String _nativeStatus = 'unverified';
  ContourGeometry? _geometry;
  Path? _shape;
  _ContourDeclaredSource? _declaredSource;
  Rect _shapeBounds = Rect.zero;
  int _captureCount = 0;
  int _nativeTraceSources = 0;
  int _nativeTraceAdmissionFallbacks = 0;
  int _traceCaptureWidth = 0;
  int _traceCaptureHeight = 0;
  int _traceCaptureCount = 0;
  int _proofCaptureCount = 0;
  int _geometryCapacityExceededCount = 0;
  bool _geometryCapacityExceeded = false;
  int? _capacityRejectedRevision;
  int _contentRevision = 0;
  int _lifetime = 0;
  bool _scheduled = false;
  bool _running = false;
  bool _pending = false;
  ContourTraceAdmissionRequest? _workRequest;
  Completer<void>? _workCancellation;

  @override
  bool get isRepaintBoundary => true;

  void configure({
    required Color color,
    required double amount,
    required List<Shadow> shadows,
    required double pixelRatio,
    required bool deferPrewarm,
    ContourController? controller,
    bool prepareWhenHidden = false,
    Widget? source,
  }) {
    if (!identical(_controller, controller)) {
      if (attached) _controller?._detach(this);
      _controller = controller;
      if (attached) _controller?._attach(this, isReady: _initialReady);
    }
    if (_prepareWhenHidden != prepareWhenHidden) {
      _prepareWhenHidden = prepareWhenHidden;
      if (prepareWhenHidden && !_initialReady) _schedule();
    }
    if (!identical(_sourceWidget, source)) {
      _sourceWidget = source;
      if (_prepareWhenHidden) contentChanged();
    }
    if (_deferPrewarm != deferPrewarm) {
      _deferPrewarm = deferPrewarm;
      if (!deferPrewarm && attached && _hasDecoration && !_preferNativeComposite) {
        _acquireProcessor();
        _ContourProcessor.prepare();
      }
    }
    final shapeChanged = _pixelRatio != pixelRatio;
    final amountChanged = _amount != amount;
    final shadowsChanged = !listEquals(_shadows, shadows);
    if (_color == color && _amount == amount && !shadowsChanged && !shapeChanged) return;
    if (_compositeBacking.ready || _compositeBacking.pending) {
      // A compound bitmap cannot animate decoration independently. Once the
      // style changes, keep reusable stock geometry for this unchanged source.
      final source = shapeChanged ? null : _compositeBacking.retainSource();
      contentChanged();
      _compositeStyleSource = source;
    }
    if (_color != color) {
      _color = color;
      _colorPaint.colorFilter = ColorFilter.mode(_color, BlendMode.srcIn);
    }
    if (_amount != amount) {
      _observeAmountChange();
      _amount = amount;
      _strokePaint.strokeWidth = _amount * 2;
    }
    if (shadowsChanged) {
      _shadows = List.of(shadows);
      _configureShadowPaints();
    }
    _pixelRatio = pixelRatio;
    if (shapeChanged) {
      _compositeStyleSource = null;
      _cancelQueuedWork();
      _nativeText.dispose();
      _nativeActive = false;
      _nativeAcceptedSettings = null;
      _nativeMaskSourceId = null;
      _nativeMaskSourceBytes = 0;
      _nativeVerificationRevision = null;
      _nativeStatus = 'unverified';
      _contentRevision++;
      _replaceGeometry(null);
    }
    if (shapeChanged || shadowsChanged) _shadowAtlas.invalidate();
    if (shapeChanged || amountChanged || shadowsChanged) {
      if (_nativeActive) {
        _shadowCache.invalidate();
        _nativeNeedsShadow = true;
      } else {
        _scheduleShadowCache();
      }
    }
    if (!_hasDecoration) {
      _cancelQueuedWork();
      _pending = false;
      _releaseProcessor();
    } else if (_shape == null) {
      _schedule();
    }
    _syncReadiness();
    markNeedsPaint();
  }

  void _observeAmountChange() {
    if (_atlasActivated) return;
    final now = SchedulerBinding.instance.currentFrameTimeStamp.inMicroseconds;
    if (_amountChanges == 0 || now - _lastAmountChangeUs > 300000) {
      _amountChanges = 0;
      _amountChangesStartedUs = now;
    }
    _lastAmountChangeUs = now;
    _amountChanges++;
    if (_amountChanges >= 3 && now - _amountChangesStartedUs >= 120000) _atlasActivated = true;
  }

  void _configurePaints() {
    _strokePaint.strokeWidth = _amount * 2;
    _colorPaint.colorFilter = ColorFilter.mode(_color, BlendMode.srcIn);
    _configureShadowPaints();
  }

  void _configureShadowPaints() {
    _knownBoxShadowPaints = null;
    _shadowPaints = [
      for (final shadow in _shadows)
        Paint()
          ..colorFilter = ColorFilter.mode(shadow.color, BlendMode.srcIn)
          ..imageFilter = (shadow.blurRadius == 0
              ? null
              : ui.ImageFilter.blur(sigmaX: shadow.blurSigma, sigmaY: shadow.blurSigma)),
    ];
  }

  bool get _hasDecoration => _color.a > 0 || _shadows.any((shadow) => shadow.color.a > 0);

  void _replaceGeometry(ContourGeometry? next) {
    if (identical(_geometry, next)) {
      _syncReadiness();
      return;
    }
    _geometry = next;
    _shape = next?.shape;
    _shapeBounds = next?.bounds ?? Rect.zero;
    _syncReadiness();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _viewMetricsRegistration = _ContourViewMetricsObserver.shared.register(this);
    _controller?._attach(this, isReady: _initialReady);
    if (_hasDecoration) ContourInitialFrameFence.shared.invalidateEpoch();
    _ContourNativeTextCache.acquire();
    PaintingBinding.instance.systemFonts.addListener(contentChanged);
    if (_hasDecoration && !_deferPrewarm && !_preferNativeComposite) {
      _acquireProcessor();
      _ContourProcessor.prepare();
    }
    _schedule();
  }

  @override
  void detach() {
    _ContourViewMetricsObserver.shared.unregister(_viewMetricsRegistration);
    _viewMetricsRegistration = null;
    _compositeStyleSource = null;
    _boxGaussianShadow.dispose();
    _preparationRequested = false;
    _controller?._detach(this);
    _clearDeclaredSource();
    _cancelQueuedWork();
    PaintingBinding.instance.systemFonts.removeListener(contentChanged);
    _ContourNativeTextCache.release();
    _lifetime++;
    _hasPresented = false;
    _initialFallback = false;
    _compositionCacheKey = null;
    _firstPresentationFrameNumber = -1;
    _firstPresentationHasContour = null;
    _lastMainCompositionFrameNumber = -1;
    _lastMainCompositionHasContent = false;
    _lastMainCompositionHasContour = false;
    _replaceGeometry(null);
    _shadowCache.invalidate();
    _shadowAtlas.invalidate();
    _nativeText.dispose();
    _nativeActive = false;
    _nativeAcceptedSettings = null;
    _nativeMaskSourceId = null;
    _nativeMaskSourceBytes = 0;
    _nativeVerificationRevision = null;
    _nativeStatus = 'unverified';
    _decorationLayer.layer = null;
    _releaseProcessor(force: true);
    super.detach();
  }

  void _viewMetricsChanged() {
    final source = child;
    if ((!_compositeBacking.ready && !_compositeBacking.pending) ||
        source is! _RenderContourCapture ||
        _compositeBacking._viewCurrent(this, source)) {
      return;
    }
    contentChanged();
    markNeedsPaint();
    SchedulerBinding.instance.scheduleFrame();
  }

  void sourceComposed() {
    final source = child as _RenderContourCapture?;
    if (source != null && _compositeBacking.current(this, source)) return;
    final declared = _declaredSource;
    if (declared != null) {
      final capture = child! as _RenderContourCapture;
      if (declared.isCurrent(capture)) return;
      contentChanged();
      _tryDeclaredGeometry();
      markNeedsPaint();
      // Composition can discover changes after painting, when dirtying paint
      // alone cannot request a frame. Adopted paths cancel queued capture work.
      SchedulerBinding.instance.scheduleFrame();
      return;
    }
    final expected = _compositionCacheKey;
    _compositionCacheKey = null;
    if (expected != null && _shape != null) {
      final capture = child! as _RenderContourCapture;
      if (_ContourNativeTextCache.key(capture, _pixelRatio, capture.paintBounds) == expected) return;
    }
    contentChanged();
  }

  void contentChanged() {
    final styleSource = _compositeStyleSource;
    if (styleSource != null) {
      final capture = child;
      final layer = capture is _RenderContourCapture ? capture.captureLayer : null;
      final stamp = styleSource.stamp;
      if (layer == null ||
          capture!.paintBounds != styleSource.bounds ||
          !stamp.isCurrent(
            root: layer,
            bounds: stamp.bounds,
            pixelRatio: stamp.pixelRatio,
            generation: stamp.generation,
          )) {
        _compositeStyleSource = null;
      }
    }
    _clearDeclaredSource();
    _cancelQueuedWork();
    _initialFallback = false;
    _compositionCacheKey = null;
    _nativeVerificationRevision = null;
    _nativeAcceptedSettings = null;
    _nativeMaskSourceId = null;
    _nativeMaskSourceBytes = 0;
    _nativeStatus = 'unverified';
    _nativeText.dispose();
    _nativeActive = false;
    _contentRevision++;
    _replaceGeometry(null);
    _shadowCache.invalidate();
    _shadowAtlas.invalidate();
    _atlasActivated = false;
    _amountChanges = 0;
    _schedule();
  }

  void _cancelQueuedWork() {
    if (_compositeBacking.ready || _compositeBacking.pending) _decorationLayer.layer = null;
    _compositeBacking.invalidate();
    final proofToken = _proofToken;
    _proofToken = null;
    if (proofToken != null) ContourNativeProofQueue.shared.cancel(proofToken);
    _proofRequest?.cancel();
    _proofRequest = null;
    final proofCancellation = _proofCancellation;
    _proofCancellation = null;
    if (proofCancellation != null && !proofCancellation.isCompleted) proofCancellation.complete();
    final proofCompletion = _proofCompletion;
    _proofCompletion = null;
    if (proofCompletion != null && !proofCompletion.isCompleted) proofCompletion.complete();
    _proofSettings = null;
    _proofMayStart = false;
    _proofWakeScheduled = false;
    _awaitedProof = null;
    _proofPresentation = null;
    _nativeProofPending = false;
    _workRequest?.cancel();
    _workRequest = null;
    final cancellation = _workCancellation;
    if (cancellation != null && !cancellation.isCompleted) cancellation.complete();
  }

  bool get _useNativeText => _ContourNativeText.accepts((child as _RenderContourCapture?)?.child);

  void _acquireProcessor() {
    if (_processorAcquired) return;
    _processorAcquired = true;
    _ContourProcessor.acquire();
  }

  void _releaseProcessor({bool force = false}) {
    // Cancelled work may still own a readback or trace. Let its existing
    // cleanup finish before dropping the worker; detachment cancels immediately.
    if (!_processorAcquired || (!force && (_running || _proofRunning))) return;
    _processorAcquired = false;
    _ContourProcessor.release();
  }

  void _schedule() {
    if (!_hasDecoration || _capacityRejectedRevision == _contentRevision) return;
    _pending = true;
    if (_scheduled || !attached) return;
    if (!_deferPrewarm && !_preferNativeComposite) {
      _acquireProcessor();
      _ContourProcessor.prepare();
    }
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!attached || !_pending) return;
      markNeedsPaint();
      if (!(child! as _RenderContourCapture).hasSize) return;
      if (!_running && (_prepareWhenHidden || _preparationRequested)) _prepareHiddenSource();
      if (!_running && _hasDecoration && (!_prepareWhenHidden || _shape == null)) unawaited(_generate());
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void performLayout() {
    super.performLayout();
    if (_pending && (_prepareWhenHidden || _preparationRequested)) _schedule();
  }

  void _sourcePainted() {
    if (_shape == null && !_running && !_scheduled && _hasDecoration) _schedule();
  }

  void _requestPreparation() {
    if (!attached) return;
    _preparationRequested = true;
    contentChanged();
    markNeedsPaint();
  }

  void _sourceInvalidated() {
    if (!_prepareWhenHidden || _preparingSource || !attached || _shape == null) return;
    contentChanged();
  }

  void _prepareHiddenSource() {
    final capture = child as _RenderContourCapture?;
    if (capture == null || !capture.hasSize) return;
    _tryDeclaredGeometry();
    if (_shape != null) {
      _pending = false;
      return;
    }
    _preparingSource = true;
    try {
      // Explicit preparation paints current laid-out content, including dirty
      // descendant repaint boundaries, without exposing it in the app scene.
      capture.markNeedsPaint();
      PaintingContext.repaintCompositedChild(capture, debugAlsoPaintedParent: true);
    } finally {
      _preparingSource = false;
    }
    _tryWarmGeometry();
  }

  void _syncReadiness() {
    if (!attached) return;
    final ready = _initialReady;
    if (ready) _preparationRequested = false;
    _controller?._update(this, isReady: ready);
    if (_reportedReady == ready) return;
    _reportedReady = ready;
    if (!ready) return;
    RenderObject descendant = this;
    var ancestor = parent;
    while (ancestor != null) {
      if (!ancestor.paintsChild(descendant)) break;
      if (ancestor is _RenderContour &&
          !ancestor._initialReady &&
          (ancestor._prepareWhenHidden || ancestor._preparationRequested)) {
        ancestor._schedule();
        break;
      }
      descendant = ancestor;
      ancestor = ancestor.parent;
    }
  }

  Future<void> _generate() async {
    _running = true;
    // Continuous live updates must not hold other owners' optional work.
    final initialPresentation = !_hasPresented;
    if (initialPresentation) ContourInitialFrameFence.shared.beginForeground();
    ContourNativeProofQueue.shared.beginInitial();
    var activeLifetime = _lifetime;
    var activeRevision = _contentRevision;
    Completer<void>? activeCancellation;
    try {
      while (_pending && attached && _hasDecoration) {
        _pending = false;
        _geometryCapacityExceeded = false;
        _ContourNativeTextCacheKey? cacheOwnerKey;
        ContourTraceAdmissionLease? workLease;
        ByteData? bytes;
        List<Float64List>? contours;
        final cancellation = Completer<void>();
        activeCancellation = cancellation;
        _workCancellation = cancellation;
        try {
          final lifetime = _lifetime;
          final revision = _contentRevision;
          activeLifetime = lifetime;
          activeRevision = revision;
          final capture = child! as _RenderContourCapture;
          final captureLayer = capture.captureLayer;
          final bounds = capture.paintBounds;
          if (capture.hasPendingContour || captureLayer == null) continue;
          if (_preferNativeComposite) {
            final accepted = await _compositeBacking.prepare(
              this,
              capture,
              lifetime: lifetime,
              revision: revision,
              cancellation: cancellation,
            );
            if (!attached || lifetime != _lifetime) return;
            if (revision != _contentRevision || cancellation.isCompleted) continue;
            if (accepted) continue;
          }
          _acquireProcessor();
          _ContourProcessor.prepare();
          if (!captureLayer.supportsRasterization() || bounds.isEmpty || !bounds.isFinite) {
            _initialFallback = true;
            _syncReadiness();
            markNeedsPaint();
            continue;
          }
          final proofEligible = _useNativeText;
          final proofSettings = proofEligible ? _sourceSettings(capture) : null;
          final cacheKey = _ContourNativeTextCache.key(capture, _pixelRatio, bounds);
          if (cacheKey != null) {
            final claim = _ContourNativeTextCache.obtain(cacheKey);
            if (claim.owner) {
              cacheOwnerKey = cacheKey;
            }
            var entry = claim.value;
            if (claim.wait != null) {
              _nativeStatus = 'waiting';
              entry = await Future.any([
                claim.wait!,
                cancellation.future.then<_ContourNativeTextCacheEntry?>((_) => null),
              ]);
            }
            if (!attached || lifetime != _lifetime) return;
            if (revision != _contentRevision || cancellation.isCompleted || !_hasDecoration) continue;
            if (entry != null && _ContourNativeTextCache.key(capture, _pixelRatio, capture.paintBounds) == cacheKey) {
              _applyNativeCache(capture, entry, cacheKey: cacheKey);
              continue;
            }
          }
          var captureBounds = bounds;
          var ratio = _captureRatio(captureBounds);
          var captureWidth = 0;
          var captureHeight = 0;
          var nativeTrace = false;
          var padding = 1 / ratio;
          var sampleScale = 1.0;
          for (var qualityAttempt = 0; qualityAttempt < 4; qualityAttempt++) {
            padding = math.max(padding, 1 / (_captureRatio(bounds.inflate(padding)) * sampleScale));
            for (var attempt = 0; attempt < 5; attempt++) {
              captureBounds = bounds.inflate(padding);
              ratio = _captureRatio(captureBounds) * sampleScale;
              captureWidth = (captureBounds.width * ratio).ceil();
              captureHeight = (captureBounds.height * ratio).ceil();
              // A retry has discarded its readback before requesting a different
              // reservation. Never hold a smaller lease while waiting to grow it.
              workLease?.release();
              workLease = null;
              final legacyBytes = _workingBytes(captureWidth, captureHeight, ratio);
              final extraSourceBytes = _nativeTracePolicy.additionalSourceBytesWithinBudget(
                pixels: captureWidth * captureHeight,
                legacyBytes: legacyBytes,
                budgetBytes: ContourWorkBudget.shared.maxBytes,
              );
              nativeTrace = extraSourceBytes > 0;
              final request = _ContourProcessor.traceAdmission.request(
                width: captureWidth,
                height: captureHeight,
                legacyBytes: legacyBytes + extraSourceBytes,
                extraSourceBytes: extraSourceBytes,
                owner: cancellation,
              );
              _workRequest = request;
              workLease = await request.future;
              if (identical(_workRequest, request)) _workRequest = null;
              if (!attached || lifetime != _lifetime || revision != _contentRevision || cancellation.isCompleted) {
                break;
              }
              if (workLease == null) {
                _capacityRejectedRevision = revision;
                _initialFallback = true;
                _syncReadiness();
                markNeedsPaint();
                break;
              }
              if (!identical(capture.captureLayer, captureLayer) || capture.paintBounds != bounds) {
                contentChanged();
                break;
              }
              ui.Image? image;
              try {
                _captureCount++;
                _traceCaptureCount++;
                captureLayer.capturing = true;
                final captureFuture = _ContourSourcePreflight.observe(
                  () => captureLayer.toImage(captureBounds, pixelRatio: ratio),
                );
                captureLayer.capturing = false;
                image = await captureFuture;
                if (capture.hasPendingContour) {
                  contentChanged();
                  break;
                }
                if (!attached ||
                    lifetime != _lifetime ||
                    revision != _contentRevision ||
                    cancellation.isCompleted ||
                    !_hasDecoration) {
                  break;
                }
                bytes = await image.toByteData();
                if (!attached ||
                    lifetime != _lifetime ||
                    revision != _contentRevision ||
                    cancellation.isCompleted ||
                    bytes == null) {
                  break;
                }
                if (!_touchesBoundary(bytes, image.width, image.height) || attempt == 4) break;
                bytes = null;
                padding *= 4;
              } finally {
                captureLayer.capturing = false;
                image?.dispose();
              }
            }
            if (!attached || lifetime != _lifetime) return;
            if (revision != _contentRevision || cancellation.isCompleted || bytes == null || !_hasDecoration) break;
            _traceCaptureWidth = captureWidth;
            _traceCaptureHeight = captureHeight;
            if (nativeTrace) {
              _nativeTraceSources++;
            } else if (_nativeTracePolicy.isSupported &&
                captureWidth * captureHeight >= ContourNativeTracePolicy.minimumPixels) {
              _nativeTraceAdmissionFallbacks++;
            }
            final result = await _ContourProcessor.trace(
              bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
              captureWidth,
              captureHeight,
              pixelRatio: ratio,
              admission: workLease,
              nativeTrace: nativeTrace,
            );
            if (!attached || lifetime != _lifetime) return;
            if (revision != _contentRevision || cancellation.isCompleted || result == null || !_hasDecoration) break;
            if (result.capacityExceeded) {
              _geometryCapacityExceeded = true;
              _geometryCapacityExceededCount++;
              bytes = null;
              workLease?.release();
              workLease = null;
              if (qualityAttempt == 3) {
                _capacityRejectedRevision = revision;
                _initialFallback = true;
                _syncReadiness();
                markNeedsPaint();
                _pending = false;
                break;
              }
              sampleScale *= .5;
              continue;
            }
            _geometryCapacityExceeded = false;
            contours = result.contours;
            break;
          }
          if (contours == null || bytes == null) continue;
          if (!identical(capture.captureLayer, captureLayer) ||
              capture.paintBounds != bounds ||
              capture.hasPendingContour) {
            contentChanged();
            continue;
          }
          // Decoration-only changes do not invalidate the captured content.
          // Consume their redundant request using this same accurate geometry.
          _pending = false;
          final geometry = ContourGeometryCache.instance.obtain(
            contours,
            pixelRatio: ratio,
            origin: Offset(captureBounds.left, captureBounds.top),
          );
          _replaceGeometry(geometry);
          final geometryBytes = geometry.estimatedBytes;
          // Picture byte counts omit referenced glyph resources. A bounded key
          // includes every source string at two bytes per UTF-16 code unit;
          // this allowance reserves at least 32 bytes per unit plus geometry
          // for every retained amount. Unknown/unbounded sources paint live.
          _nativeMaskSourceBytes = cacheKey == null
              ? ContourNativeMaskPictureCache.maximumEstimatedBytes
              : cacheKey.estimatedBytes * 16 + geometryBytes;
          _scheduleShadowCache();
          markNeedsPaint();
          // Release readback and tracing scratch before optional native work.
          // The visible generic contour is already complete and usable.
          bytes = null;
          contours = null;
          workLease?.release();
          workLease = null;
          _publishGeometry(
            capture: capture,
            sourceBounds: bounds,
            captureBounds: captureBounds,
            captureLayer: captureLayer,
            width: captureWidth,
            height: captureHeight,
            ratio: ratio,
            revision: revision,
            lifetime: lifetime,
            cacheKey: cacheOwnerKey,
            proofEligible: proofEligible && _useNativeText,
            proofSettings: proofSettings,
          );
          cacheOwnerKey = null;
        } finally {
          bytes = null;
          contours = null;
          workLease?.release();
          if (identical(_workCancellation, cancellation)) _workCancellation = null;
          if (cacheOwnerKey != null) _ContourNativeTextCache.complete(cacheOwnerKey, null);
        }
      }
    } catch (error, stack) {
      if (attached &&
          _hasDecoration &&
          _lifetime == activeLifetime &&
          _contentRevision == activeRevision &&
          !(activeCancellation?.isCompleted ?? false)) {
        _initialFallback = true;
        _syncReadiness();
        markNeedsPaint();
      }
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'Contour'));
    } finally {
      ContourNativeProofQueue.shared.endInitial();
      if (initialPresentation) ContourInitialFrameFence.shared.endForeground();
      if (!_nativeProofPending && (_nativeStatus == 'waiting' || _nativeStatus == 'checking')) {
        _nativeStatus = 'unverified';
      }
      _running = false;
      if (!_hasDecoration || _declaredSource != null || _compositeBacking.ready) _releaseProcessor();
      if (_pending && attached) _schedule();
    }
  }

  void _applyNativeCache(
    _RenderContourCapture capture,
    _ContourNativeTextCacheEntry entry, {
    required _ContourNativeTextCacheKey cacheKey,
    bool repaint = true,
  }) {
    final source = _ContourNativeText.paragraph(capture.child)!;
    final translation = source.getTransformTo(capture).getTranslation();
    final origin = Offset(translation.x, translation.y);
    _replaceGeometry(entry.geometry);
    _nativeAcceptedSettings = (_ContourNativeText.signature(source), origin);
    _nativeMaskSourceId = entry.nativeMaskSourceId;
    _nativeMaskSourceBytes = entry.nativeMaskSourceBytes;
    _nativeOffset = origin;
    _nativeStatus = entry.proof != null ? 'waiting' : (entry.native ? 'accepted-shared' : 'rejected-shared');
    _nativeActive = entry.native;
    _scheduleShadowCache();
    _watchProof(entry, cacheKey);
    if (repaint) markNeedsPaint();
  }

  void _watchProof(_ContourNativeTextCacheEntry entry, _ContourNativeTextCacheKey cacheKey) {
    _proofPresentation = entry.onPresented;
    final future = entry.proof;
    if (future == null || identical(_awaitedProof, future)) return;
    _awaitedProof = future;
    _nativeProofPending = true;
    final weak = WeakReference(this);
    final revision = _contentRevision;
    final lifetime = _lifetime;
    unawaited(
      future.then((next) {
        final owner = weak.target;
        if (owner == null ||
            !owner.attached ||
            owner._lifetime != lifetime ||
            owner._contentRevision != revision ||
            !identical(owner._awaitedProof, future)) {
          return;
        }
        owner
          .._awaitedProof = null
          .._proofPresentation = null
          .._nativeProofPending = false;
        if (next == null || !identical(owner._geometry, entry.geometry)) {
          if (owner._nativeStatus == 'waiting') owner._nativeStatus = 'unverified';
          return;
        }
        final capture = owner.child! as _RenderContourCapture;
        if (_ContourNativeTextCache.key(capture, owner._pixelRatio, capture.paintBounds) != cacheKey) {
          if (owner._nativeStatus == 'waiting') owner._nativeStatus = 'unverified';
          return;
        }
        owner._applyNativeCache(capture, next, cacheKey: cacheKey);
      }),
    );
  }

  void _publishGeometry({
    required _RenderContourCapture capture,
    required Rect sourceBounds,
    required _ContourLayer captureLayer,
    required Rect captureBounds,
    required int width,
    required int height,
    required double ratio,
    required int revision,
    required int lifetime,
    required _ContourNativeTextCacheKey? cacheKey,
    required bool proofEligible,
    required Object? proofSettings,
  }) {
    if (proofEligible && _sourceSettings(capture) != proofSettings) {
      if (cacheKey != null) _ContourNativeTextCache.complete(cacheKey, null);
      contentChanged();
      return;
    }
    final geometry = _geometry!;
    final proofBytes = proofEligible ? _proofBytes(width, height, ratio) : null;
    if (proofBytes == null) {
      if (proofEligible) _nativeStatus = 'oversize';
      if (cacheKey != null) {
        _ContourNativeTextCache.complete(
          cacheKey,
          _ContourNativeTextCacheEntry(
            geometry,
            geometry.estimatedBytes,
            native: false,
            nativeMaskSourceId: null,
            nativeMaskSourceBytes: 0,
          ),
        );
      }
      return;
    }
    _proofSettings = proofSettings;
    final cancellation = Completer<void>();
    final completion = Completer<_ContourNativeTextCacheEntry?>();
    final token = Object();
    final weak = WeakReference(this);
    final layer = WeakReference(captureLayer);
    final initial = _ContourNativeTextCacheEntry(
      geometry,
      geometry.estimatedBytes,
      native: false,
      nativeMaskSourceId: null,
      nativeMaskSourceBytes: 0,
      proof: completion.future,
      onPresented: () {
        final owner = weak.target;
        if (owner == null || owner._lifetime != lifetime || !identical(owner._proofToken, token)) return;
        owner._scheduleProofAfterPresentation(token, lifetime);
      },
    );
    void finish(_ContourNativeTextCacheEntry? result) {
      if (completion.isCompleted) return;
      final next =
          result ??
          _ContourNativeTextCacheEntry(
            geometry,
            geometry.estimatedBytes,
            native: false,
            nativeMaskSourceId: null,
            nativeMaskSourceBytes: 0,
          );
      if (cacheKey != null) _ContourNativeTextCache.replace(cacheKey, initial, next);
      completion.complete(next);
    }

    if (cacheKey != null) _ContourNativeTextCache.complete(cacheKey, initial);
    _proofToken = token;
    _proofPresentation = initial.onPresented;
    _proofCancellation = cancellation;
    _proofCompletion = completion;
    _nativeProofPending = true;
    _proofMayStart = false;
    _nativeStatus = 'waiting';
    final queued = ContourNativeProofQueue.shared.enqueue(
      owner: token,
      canRun: () {
        final owner = weak.target;
        return owner != null && owner._proofMayStart;
      },
      run: () async {
        final owner = weak.target;
        if (owner == null) {
          finish(null);
          return;
        }
        try {
          final result = await owner._runNativeProof(
            token: token,
            cancellation: cancellation,
            captureLayer: layer,
            sourceBounds: sourceBounds,
            captureBounds: captureBounds,
            width: width,
            height: height,
            ratio: ratio,
            revision: revision,
            lifetime: lifetime,
            bytes: proofBytes,
            geometry: geometry,
          );
          finish(result);
        } finally {
          finish(null);
          if (identical(owner._proofToken, token)) {
            owner
              .._proofToken = null
              .._proofCancellation = null
              .._proofCompletion = null
              .._proofPresentation = null
              .._proofSettings = null
              .._nativeProofPending = false;
            if (owner._nativeStatus == 'waiting' || owner._nativeStatus == 'checking') {
              owner._nativeStatus = 'unverified';
            }
            owner.markNeedsPaint();
          }
        }
      },
      onCancel: () => finish(null),
    );
    if (!queued) {
      finish(null);
      _proofToken = null;
      _proofCancellation = null;
      _proofCompletion = null;
      _proofPresentation = null;
      _proofSettings = null;
      _nativeProofPending = false;
      _nativeStatus = 'unverified';
    }
  }

  Future<_ContourNativeTextCacheEntry?> _runNativeProof({
    required Object token,
    required Completer<void> cancellation,
    required WeakReference<_ContourLayer> captureLayer,
    required Rect sourceBounds,
    required Rect captureBounds,
    required int width,
    required int height,
    required double ratio,
    required int revision,
    required int lifetime,
    required int bytes,
    required ContourGeometry geometry,
  }) async {
    bool current() {
      if (!attached ||
          _lifetime != lifetime ||
          _contentRevision != revision ||
          cancellation.isCompleted ||
          !identical(_proofToken, token) ||
          !identical(_geometry, geometry) ||
          !_hasDecoration ||
          !_useNativeText) {
        return false;
      }
      final capture = child! as _RenderContourCapture;
      final source = _ContourNativeText.paragraph(capture.child)!;
      final translation = source.getTransformTo(capture).getTranslation();
      return !capture.hasPendingContour &&
          identical(capture.captureLayer, captureLayer.target) &&
          capture.paintBounds == sourceBounds &&
          (_ContourNativeText.signature(source), Offset(translation.x, translation.y)) == _proofSettings;
    }

    if (!current()) return null;
    _proofRunning = true;
    ContourWorkBudgetLease? lease;
    ui.Image? image;
    ByteData? original;
    try {
      while (current()) {
        if (!await ContourInitialFrameFence.shared.wait(cancelled: cancellation.future)) return null;
        if (!current()) return null;
        if (!ContourInitialFrameFence.shared.ready) continue;
        final request = ContourWorkBudget.shared.request(bytes: bytes, owner: cancellation, background: true);
        _proofRequest = request;
        lease = await request.future;
        if (identical(_proofRequest, request)) _proofRequest = null;
        if (lease == null || !current()) return null;
        if (ContourInitialFrameFence.shared.ready) break;
        // A new foreground request must not wait behind a background lease.
        lease.release();
        lease = null;
      }
      if (lease == null || !current()) return null;
      final capture = child! as _RenderContourCapture;
      final layer = captureLayer.target!;
      _captureCount++;
      _proofCaptureCount++;
      layer.capturing = true;
      final future = _ContourSourcePreflight.observe(
        () => layer.toImage(captureBounds, pixelRatio: ratio),
      );
      layer.capturing = false;
      image = await future;
      if (!current() || image.width != width || image.height != height) return null;
      original = await image.toByteData();
      image.dispose();
      image = null;
      if (!current() || original == null) return null;
      await _verifyNative(
        capture,
        original.buffer.asUint8List(original.offsetInBytes, original.lengthInBytes),
        width,
        height,
        captureBounds,
        ratio,
      );
      if (!current()) return null;
      return _ContourNativeTextCacheEntry(
        geometry,
        geometry.estimatedBytes,
        native: _nativeActive,
        nativeMaskSourceId: _nativeMaskSourceId,
        nativeMaskSourceBytes: _nativeActive ? _nativeMaskSourceBytes : 0,
      );
    } catch (error, stack) {
      if (attached && _lifetime == lifetime && _contentRevision == revision && identical(_proofToken, token)) {
        _nativeStatus = 'error';
      }
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'Contour'));
      return null;
    } finally {
      captureLayer.target?.capturing = false;
      original = null;
      image?.dispose();
      lease?.release();
      _proofRunning = false;
      if (!_hasDecoration || _declaredSource != null) _releaseProcessor();
    }
  }

  Object _sourceSettings(_RenderContourCapture capture) {
    final source = _ContourNativeText.paragraph(capture.child)!;
    final translation = source.getTransformTo(capture).getTranslation();
    return (_ContourNativeText.signature(source), Offset(translation.x, translation.y));
  }

  bool _prepareBoxGaussian() {
    final geometry = _declaredSource?.knownBox;
    double? pixelRatio;
    if (attached && _boxGaussianShadow.accepts(geometry, _amount, _shadows, null)) {
      final matrix = getTransformTo(null).storage;
      final scale = matrix[0];
      if (scale > 0 &&
          scale == matrix[5] &&
          matrix[1] == 0 &&
          matrix[2] == 0 &&
          matrix[3] == 0 &&
          matrix[4] == 0 &&
          matrix[6] == 0 &&
          matrix[7] == 0 &&
          matrix[8] == 0 &&
          matrix[9] == 0 &&
          matrix[10] == 1 &&
          matrix[11] == 0 &&
          matrix[15] == 1) {
        pixelRatio = _pixelRatio * scale;
      }
    }
    _boxGaussianShadow.configure(geometry, _amount, _shadows, pixelRatio);
    return pixelRatio != null;
  }

  bool get _initialReady => !_hasDecoration || _shape != null || _initialFallback;

  void _clearDeclaredSource() {
    _declaredSource = null;
  }

  void _tryDeclaredGeometry() {
    if (!_hasDecoration) return;
    final capture = child! as _RenderContourCapture;
    if (_shape != null && (_declaredSource?.isCurrent(capture) ?? false)) return;
    final next = _ContourDeclaredSource.resolve(capture);
    if (next == null) return;
    _cancelQueuedWork();
    _clearDeclaredSource();
    _pending = false;
    _initialFallback = false;
    _nativeActive = false;
    _nativeStatus = 'declared-path';
    _shadowCache.invalidate();
    _shadowAtlas.invalidate();
    _declaredSource = next;
    _replaceGeometry(ContourGeometry.declared(next.path));
    _releaseProcessor();
    _scheduleShadowCache();
  }

  void _tryWarmGeometry() {
    if (_preferNativeComposite) return;
    if (!_hasDecoration || _shape != null || _initialFallback) return;
    final capture = child! as _RenderContourCapture;
    if (capture.hasPendingContour) return;
    final bounds = capture.paintBounds;
    if (bounds.isEmpty || !bounds.isFinite) return;
    final key = _ContourNativeTextCache.key(capture, _pixelRatio, bounds);
    if (key == null) return;
    final entry = _ContourNativeTextCache.peek(key);
    if (entry == null) return;
    _pending = false;
    _compositionCacheKey = key;
    _applyNativeCache(capture, entry, cacheKey: key, repaint: false);
  }

  bool _canPresent(Path? recordedShape, int revision) {
    final hasContour = recordedShape != null && identical(_shape, recordedShape) && _contentRevision == revision;
    final ready = _hasPresented || (!_hasDecoration || _initialFallback || hasContour);
    if (!_ContourSourcePreflight.observing &&
        SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      final frame = WidgetsBinding.instance.platformDispatcher.frameData.frameNumber;
      _lastMainCompositionFrameNumber = frame;
      _lastMainCompositionHasContent = ready;
      _lastMainCompositionHasContour = ready && hasContour;
      if (ready) {
        if (!_hasPresented) {
          _hasPresented = true;
          _firstPresentationFrameNumber = frame;
          _firstPresentationHasContour = hasContour;
          markNeedsSemanticsUpdate();
        }
        _commitNestedPresentations(_decorationLayer.layer);
        if (hasContour) _proofPresentation?.call();
      }
    }
    return ready;
  }

  void _scheduleProofAfterPresentation(Object token, int lifetime) {
    if (_proofMayStart || _proofWakeScheduled) return;
    _proofWakeScheduled = true;
    final weak = WeakReference(this);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final owner = weak.target;
      if (owner == null) return;
      owner._proofWakeScheduled = false;
      if (!owner.attached || owner._lifetime != lifetime || !identical(owner._proofToken, token)) return;
      owner._proofMayStart = true;
      ContourNativeProofQueue.shared.wake();
    });
  }

  void _commitNestedPresentations(ContainerLayer? root) {
    var layer = root?.firstChild;
    while (layer != null) {
      if (layer is _ContourDecorationLayer) {
        layer.canPresent();
      } else if (layer is ContainerLayer) {
        _commitNestedPresentations(layer);
      }
      layer = layer.nextSibling;
    }
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      _hasPresented && super.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_hasPresented) super.visitChildrenForSemantics(visitor);
  }

  Future<void> _verifyNative(
    _RenderContourCapture capture,
    Uint8List original,
    int originalWidth,
    int originalHeight,
    Rect captureBounds,
    double ratio,
  ) async {
    final revision = _contentRevision;
    if (_nativeVerificationRevision == revision || _shape == null) return;
    _nativeVerificationRevision = revision;
    final lifetime = _lifetime;
    final source = _ContourNativeText.paragraph(capture.child)!;
    final transform = source.getTransformTo(capture);
    final translation = transform.getTranslation();
    final origin = Offset(translation.x, translation.y);
    final settings = (_ContourNativeText.signature(source), origin);
    final padding = (ratio * 2).ceil();
    final width = originalWidth + padding * 2;
    final height = originalHeight + padding * 2;
    final bounds = Rect.fromLTWH(
      captureBounds.left - padding / ratio,
      captureBounds.top - padding / ratio,
      width / ratio,
      height / ratio,
    );
    if (width * height * 5 > _maximumVerificationPixels || width > 4096 || height * 5 > 4096) {
      _nativeStatus = 'oversize';
      return;
    }
    ui.Picture? picture;
    ui.Image? image;
    _nativeStatus = 'checking';
    try {
      _nativeText.update(source, 1);
      if (_nativeText.clipped(source)) {
        _nativeStatus = 'clipped';
        return;
      }
      _nativeVerificationCount++;
      picture = _nativeText.verificationPicture(source, _shape!, bounds, ratio, height, origin);
      image = await picture.toImage(width, height * 5);
      if (!attached || lifetime != _lifetime || revision != _contentRevision || !_hasDecoration) return;
      final bytes = await image.toByteData();
      image.dispose();
      image = null;
      picture.dispose();
      picture = null;
      if (!attached || lifetime != _lifetime || revision != _contentRevision || bytes == null) return;
      final result = await _ContourProcessor.verify(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        width,
        height,
        ratio,
        original,
        originalWidth,
        originalHeight,
        padding,
      );
      if (!attached || lifetime != _lifetime || revision != _contentRevision || result == null) return;
      final currentSource = _ContourNativeText.paragraph(capture.child);
      if (!identical(currentSource, source) || !_ContourNativeText.accepts(capture.child)) return;
      final currentTranslation = source.getTransformTo(capture).getTranslation();
      final currentOrigin = Offset(currentTranslation.x, currentTranslation.y);
      if ((_ContourNativeText.signature(source), currentOrigin) != settings) return;
      _nativeStatus = result['accepted'] == 1 ? 'accepted' : 'rejected';
      if (result['accepted'] != 1) return;
      _nativeAcceptedSettings = settings;
      _nativeMaskSourceId = Object();
      _nativeOffset = origin;
      _nativeActive = true;
      _scheduleShadowCache();
      markNeedsPaint();
    } catch (error, stack) {
      _nativeStatus = 'error';
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'Contour'),
      );
    } finally {
      image?.dispose();
      picture?.dispose();
      if (attached && lifetime == _lifetime && revision == _contentRevision) markNeedsPaint();
    }
  }

  bool _touchesBoundary(ByteData pixels, int width, int height) {
    for (var x = 0; x < width; x++) {
      if (pixels.getUint8(x * 4 + 3) != 0 || pixels.getUint8(((height - 1) * width + x) * 4 + 3) != 0) return true;
    }
    for (var y = 1; y < height - 1; y++) {
      if (pixels.getUint8(y * width * 4 + 3) != 0 || pixels.getUint8((y * width + width - 1) * 4 + 3) != 0) return true;
    }
    return false;
  }

  int _workingBytes(int width, int height, double ratio) {
    final pixels = width * height;
    // Main and worker RGBA copies, plus the coverage pass's three padded
    // byte planes and a four-byte component queue. This also covers the
    // smaller image/readback overlap before the worker receives the input.
    final cells = (width + 1) * (height + 1);
    final geometryBytes = math.min(_ContourTracer._maximumGeometryBytes, cells * 144);
    final pointScratchBytes = math.min(_ContourTracer._maximumContourPoints, cells * 2) * 128;
    // Include retained curves, their worker reply copy, native path storage,
    // and bounded point/fitting scratch before accepting a source snapshot.
    final traceBytes = pixels * 12 + (width + 2) * (height + 2) * 3 + geometryBytes * 3 + pointScratchBytes + 64 * 1024;
    return traceBytes;
  }

  int? _proofBytes(int width, int height, double ratio) {
    final padding = (ratio * 2).ceil();
    final panelWidth = width + padding * 2;
    final panelHeight = height + padding * 2;
    final panelPixels = panelWidth * panelHeight;
    if (panelPixels * 5 > _maximumVerificationPixels || panelWidth > 4096 || panelHeight * 5 > 4096) return null;
    return width * height * 8 + panelPixels * 96 + _geometry!.estimatedBytes * 3;
  }

  double _captureRatio(Rect bounds) =>
      math.min(math.max(_pixelRatio, 3), math.sqrt(_maximumPixels / (bounds.width * bounds.height)));

  Rect get _maskBounds => _shapeBounds.inflate(_amount + 1 / _pixelRatio);

  void _scheduleShadowCache() {
    if (_compositeBacking.ready || _compositeBacking.pending) return;
    if (_declaredSource?.knownBox != null &&
        _shadows
            .where((shadow) => shadow.color.a > 0)
            .every((shadow) => shadow.blurRadius > 0 && shadow.color.colorSpace == ui.ColorSpace.sRGB)) {
      _shadowCache.invalidate();
      _shadowAtlas.invalidate();
      return;
    }
    _shadowCache.invalidate();
    if (_shape == null ||
        !attached ||
        !_shadows.any((shadow) => shadow.color.a > 0) ||
        _shadows.any(
          (shadow) => shadow.color.a > 0 && shadow.blurRadius == 0,
        )) {
      return;
    }
    // Native glyph rasterization changes subpixel coverage. Keep both sampled
    // shadow caches within the verified opacity range; stronger native shadows
    // retain their exact rendering. Path masks do not share this constraint.
    if (_nativeActive && _shadows.fold<double>(0, (sum, shadow) => sum + shadow.color.a) > .2) {
      _shadowAtlas.invalidate();
      return;
    }
    if (_atlasActivated &&
        _ContourShadowImageKey._snapshot(_shadows) != null &&
        _shadows
            .where((shadow) => shadow.color.a > 0)
            .every(
              (shadow) => shadow.blurRadius >= 6 && shadow.color.colorSpace == ui.ColorSpace.sRGB,
            )) {
      final nativeMask = _nativeActive;
      final maskIdentity = nativeMask ? _nativeMaskSourceId! : _shape!;
      final nativeSettings = _nativeAcceptedSettings;
      final minimumAmount = _shadowAtlas.contains(_amount)
          ? _shadowAtlas.minimumAmount
          : (_amount / _ContourShadowAtlas.interval).floor() * _ContourShadowAtlas.interval;
      final maximumMask = _shapeBounds.inflate(
        minimumAmount + _ContourShadowAtlas.interval + 1 / _pixelRatio,
      );
      var atlasBounds = Rect.zero;
      final shadows = List<Shadow>.unmodifiable(
        _shadows.where((shadow) => shadow.color.a > 0),
      );
      for (final shadow in shadows) {
        final bounds = maximumMask.shift(shadow.offset).inflate(shadow.blurSigma * 3);
        atlasBounds = atlasBounds.isEmpty ? bounds : atlasBounds.expandToInclude(bounds);
      }
      if (_shadowAtlas.schedule(
        key: _ContourShadowAtlasKey(
          maskIdentity: maskIdentity,
          nativeMask: nativeMask,
          minimumAmount: minimumAmount,
          origin: _nativeActive ? _nativeOffset : Offset.zero,
          shadows: shadows,
          bounds: atlasBounds,
          pixelRatio: _pixelRatio,
        ),
        bounds: atlasBounds,
        shapeBounds: _shapeBounds,
        maskMargin: 1 / _pixelRatio,
        shadows: shadows,
        sourceBytes: _nativeActive
            ? _nativeMaskSourceBytes
            : _declaredSource == null
            ? _geometry!.estimatedBytes
            : _ContourKnownBoxSource.sourceBytes,
        isCurrentSource: () => nativeMask
            ? _nativeActive &&
                  identical(_nativeMaskSourceId, maskIdentity) &&
                  _useNativeText &&
                  _sourceSettings(child! as _RenderContourCapture) == nativeSettings
            : !_nativeActive &&
                  identical(_shape, maskIdentity) &&
                  (_declaredSource?.isCurrent(child! as _RenderContourCapture) ?? true),
        recordMask: _recordAtlasMask,
      )) {
        return;
      }
    } else {
      _shadowAtlas.invalidate();
    }
    var bounds = Rect.zero;
    for (final shadow in _shadows) {
      if (shadow.color.a == 0) continue;
      final shadowBounds = _maskBounds.shift(shadow.offset).inflate(shadow.blurSigma * 3);
      bounds = bounds.isEmpty ? shadowBounds : bounds.expandToInclude(shadowBounds);
    }
    final nativeMask = _nativeActive;
    final maskIdentity = nativeMask ? _nativeMaskSourceId! : _shape!;
    final nativeSettings = _nativeAcceptedSettings;
    _shadowCache.schedule(
      key: _ContourShadowImageKey(
        maskIdentity: maskIdentity,
        amount: _amount,
        nativeMask: nativeMask,
        shadows: _shadows,
        bounds: bounds,
        pixelRatio: math.min(_pixelRatio, 2),
      ),
      bounds: bounds,
      pixelRatio: _pixelRatio,
      isCurrentSource: () => nativeMask
          ? _nativeActive &&
                identical(_nativeMaskSourceId, maskIdentity) &&
                _useNativeText &&
                _sourceSettings(child! as _RenderContourCapture) == nativeSettings
          : !_nativeActive &&
                identical(_shape, maskIdentity) &&
                (_declaredSource?.isCurrent(child! as _RenderContourCapture) ?? true),
      paint: _paintShadows,
    );
  }

  @override
  Rect get paintBounds {
    var bounds = super.paintBounds;
    final compositeBounds = _compositeBacking.bounds;
    if (compositeBounds != null) return bounds.expandToInclude(compositeBounds);
    if (_shape == null) return bounds;
    final mask = _maskBounds;
    bounds = bounds.expandToInclude(mask);
    for (final shadow in _shadows) {
      bounds = bounds.expandToInclude(mask.shift(shadow.offset).inflate(shadow.blurSigma * 3));
    }
    return bounds;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    final nativeTraceStats = _ContourProcessor.nativeTraceStats;
    properties
      ..add(DiagnosticsProperty<bool>('traceNativePortSupported', _nativeTracePolicy.isSupported))
      ..add(IntProperty('traceNativePortMinimumPixels', ContourNativeTracePolicy.minimumPixels))
      ..add(IntProperty('traceNativePortSources', _nativeTraceSources))
      ..add(IntProperty('traceNativePortAdmissionFallbacks', _nativeTraceAdmissionFallbacks))
      ..add(IntProperty('traceCaptureWidth', _traceCaptureWidth))
      ..add(IntProperty('traceCaptureHeight', _traceCaptureHeight))
      ..add(IntProperty('traceNativePortCalls', nativeTraceStats['calls'] ?? 0))
      ..add(IntProperty('traceDartCalls', nativeTraceStats['dartTraces'] ?? 0))
      ..add(IntProperty('traceNativePortJobs', nativeTraceStats['jobs'] ?? 0))
      ..add(IntProperty('traceNativePortHeldBytes', nativeTraceStats['heldBytes'] ?? 0))
      ..add(IntProperty('traceNativePortWorkingBytes', nativeTraceStats['nativeOutAndWorkspaceBytes'] ?? 0))
      ..add(IntProperty('traceNativePortPeakBytes', nativeTraceStats['peakNativeBytes'] ?? 0))
      ..add(IntProperty('traceNativePortInputBytes', nativeTraceStats['inputBytesSubmitted'] ?? 0))
      ..add(IntProperty('traceNativePortOutputBytes', nativeTraceStats['kernelOutputBytes'] ?? 0))
      ..add(IntProperty('traceNativePortAcks', nativeTraceStats['acks'] ?? 0))
      ..add(IntProperty('traceNativePortInitializationFallbacks', nativeTraceStats['initializationFallbacks'] ?? 0))
      ..add(IntProperty('traceNativePortSubmitFallbacks', nativeTraceStats['submitFallbacks'] ?? 0))
      ..add(IntProperty('traceNativePortKernelFallbacks', nativeTraceStats['kernelFallbacks'] ?? 0))
      ..add(IntProperty('traceNativePortQuotaFallbacks', nativeTraceStats['quotaFallbacks'] ?? 0))
      ..add(IntProperty('traceNativePortOwners', nativeTraceStats['owners'] ?? 0))
      ..add(IntProperty('traceNativePortAffinityChecks', nativeTraceStats['handlerAffinityChecks'] ?? 0))
      ..add(IntProperty('traceNativePortAffinityFailures', nativeTraceStats['handlerAffinityFailures'] ?? 0))
      ..add(IntProperty('traceNativePortAffinityUnion', nativeTraceStats['handlerAffinityUnion'] ?? 0))
      ..add(IntProperty('captureCount', _captureCount))
      ..add(IntProperty('traceCaptureCount', _traceCaptureCount))
      ..add(IntProperty('proofCaptureCount', _proofCaptureCount))
      ..add(IntProperty('firstPresentationFrameNumber', _firstPresentationFrameNumber))
      ..add(DiagnosticsProperty<bool>('firstPresentationHasContour', _firstPresentationHasContour))
      ..add(IntProperty('lastMainCompositionFrameNumber', _lastMainCompositionFrameNumber))
      ..add(FlagProperty('lastMainCompositionHasContent', value: _lastMainCompositionHasContent, ifTrue: 'content'))
      ..add(FlagProperty('lastMainCompositionHasContour', value: _lastMainCompositionHasContour, ifTrue: 'contour'))
      ..add(FlagProperty('initialFrameFenceReady', value: ContourInitialFrameFence.shared.ready, ifTrue: 'ready'))
      ..add(IntProperty('initialFrameFenceEpoch', ContourInitialFrameFence.shared.epoch))
      ..add(IntProperty('initialFrameFenceTargetFrame', ContourInitialFrameFence.shared.targetFrame))
      ..add(StringProperty('initialFrameFenceReason', ContourInitialFrameFence.shared.reason))
      ..add(IntProperty('initialFrameFenceFallbackCount', ContourInitialFrameFence.shared.fallbackCount))
      ..add(IntProperty('initialFrameFenceCount', ContourInitialFrameFence.shared.fenceCount))
      ..add(IntProperty('nativeProofInitialWorkCount', ContourNativeProofQueue.shared.initialWorkCount))
      ..add(IntProperty('nativeProofQueueCount', ContourNativeProofQueue.shared.pendingCount))
      ..add(IntProperty('nativeProofBuildCount', ContourNativeProofQueue.shared.buildCount))
      ..add(
        IntProperty('nativeProofMaximumInitialWorkAtStart', ContourNativeProofQueue.shared.maximumInitialWorkAtStart),
      )
      ..add(IntProperty('geometryIdentity', _geometry == null ? 0 : identityHashCode(_geometry)))
      ..add(IntProperty('geometrySources', ContourGeometryCache.instance.sourceCount))
      ..add(IntProperty('geometrySourceBytes', ContourGeometryCache.instance.sourceBytes))
      ..add(IntProperty('geometrySourceHits', ContourGeometryCache.instance.sourceHits))
      ..add(IntProperty('geometrySourceBuilds', ContourGeometryCache.instance.sourceBuilds))
      ..add(IntProperty('geometryCapacityExceededCount', _geometryCapacityExceededCount))
      ..add(FlagProperty('geometryCapacityExceeded', value: _geometryCapacityExceeded, ifTrue: 'capacity exceeded'))
      ..add(IntProperty('webActiveCount', _ContourProcessor.webActiveCount))
      ..add(IntProperty('webQueuedPayloadBytes', _ContourProcessor.webQueuedPayloadBytes))
      ..add(IntProperty('workBudgetActiveBytes', ContourWorkBudget.shared.activeBytes))
      ..add(IntProperty('workBudgetPeakBytes', ContourWorkBudget.shared.peakBytes))
      ..add(IntProperty('traceSharedScratchBytes', _ContourProcessor.traceAdmission.activeScratchBytes))
      ..add(IntProperty('traceScratchPeakBytes', _ContourProcessor.traceAdmission.peakScratchBytes))
      ..add(IntProperty('traceSourcePeakBytes', _ContourProcessor.traceAdmission.peakSourceBytes))
      ..add(IntProperty('traceSharedPeakSources', _ContourProcessor.traceAdmission.peakSharedCount))
      ..add(IntProperty('traceSharedSources', _ContourProcessor.traceAdmission.sharedCount))
      ..add(IntProperty('traceLegacySources', _ContourProcessor.traceAdmission.legacyCount))
      ..add(IntProperty('traceConsumptionAcksPending', _ContourProcessor._awaitingAcknowledgements.length))
      ..add(IntProperty('traceNativeStarts', _ContourProcessor._nativeStartCount))
      ..add(IntProperty('traceNativeExits', _ContourProcessor._nativeExitCount))
      ..add(IntProperty('workBudgetPendingCount', ContourWorkBudget.shared.pendingCount))
      ..add(
        FlagProperty('knownBoxFillActive', value: _declaredSource?.knownBox != null, ifTrue: 'known box fill active'),
      )
      ..add(IntProperty('boxGaussianMeshPaintCount', _boxGaussianShadow.meshPaintCount))
      ..add(IntProperty('boxGaussianNativePaintCount', _boxGaussianNativePaintCount))
      ..add(IntProperty('boxGaussianMeshVertexCount', _boxGaussianShadow.meshVertexCount))
      ..add(IntProperty('boxGaussianMeshTriangleCount', _boxGaussianShadow.meshTriangleCount))
      ..add(IntProperty('boxGaussianMeshCacheEntries', _ContourBoxGaussianMeshCache.entries))
      ..add(IntProperty('boxGaussianMeshCacheBytes', _ContourBoxGaussianMeshCache.bytes))
      ..add(IntProperty('boxGaussianMeshActiveBytes', _ContourBoxGaussianMeshCache.activeBytes))
      ..add(IntProperty('boxGaussianMeshActiveEntries', _ContourBoxGaussianMeshCache.activeEntries))
      ..add(IntProperty('boxGaussianMeshRetainedBytes', _ContourBoxGaussianMeshCache.retainedBytes))
      ..add(IntProperty('boxGaussianMeshRetainedEntries', _ContourBoxGaussianMeshCache.retainedEntries))
      ..add(IntProperty('boxGaussianMeshBuildCount', _ContourBoxGaussianMeshCache.builds))
      ..add(IntProperty('boxGaussianMeshCacheHits', _ContourBoxGaussianMeshCache.hits))
      ..add(IntProperty('boxGaussianMeshGenerationMicroseconds', _ContourBoxGaussianMeshCache.generationMicroseconds))
      ..add(IntProperty('boxGaussianMeshCoefficientMicroseconds', _ContourBoxGaussianMeshCache.coefficientMicroseconds))
      ..add(IntProperty('boxGaussianMeshArrayMicroseconds', _ContourBoxGaussianMeshCache.arrayMicroseconds))
      ..add(
        IntProperty(
          'boxGaussianMeshNativeVerticesMicroseconds',
          _ContourBoxGaussianMeshCache.nativeVerticesMicroseconds,
        ),
      )
      ..add(FlagProperty('declaredPathActive', value: _declaredSource != null, ifTrue: 'declared path active'))
      ..add(FlagProperty('nativeTextActive', value: _nativeActive, ifTrue: 'native text active'))
      ..add(StringProperty('nativeTextStatus', _nativeStatus))
      ..add(IntProperty('nativeTextVerificationCount', _nativeVerificationCount))
      ..add(IntProperty('nativeTextCacheEntries', _ContourNativeTextCache._entries.length))
      ..add(IntProperty('nativeTextCacheBytes', _ContourNativeTextCache.estimatedBytes))
      ..add(DiagnosticsProperty<Object>('nativeMaskSourceId', _nativeMaskSourceId))
      ..add(IntProperty('nativeMaskSourceBytes', _nativeMaskSourceBytes))
      ..add(IntProperty('nativeMaskPictureEntries', ContourNativeMaskPictureCache.instance.entryCount))
      ..add(IntProperty('nativeMaskPictureBytes', ContourNativeMaskPictureCache.instance.estimatedBytes))
      ..add(IntProperty('nativeMaskPictureBuildCount', ContourNativeMaskPictureCache.instance.buildCount))
      ..add(IntProperty('nativeFillPainterCreations', _nativeText.fillPainterCreations))
      ..add(IntProperty('nativeFillLayoutBuilds', _nativeText.fillLayoutBuilds))
      ..add(IntProperty('nativeFillPaintUpdates', _nativeText.fillPaintUpdates))
      ..add(
        FlagProperty(
          'shadowAtlasActive',
          value: _atlasActivated,
          ifTrue: 'active',
        ),
      )
      ..add(
        FlagProperty(
          'shadowAtlasReady',
          value: _shadowAtlas.ready,
          ifTrue: 'ready',
        ),
      )
      ..add(IntProperty('shadowAtlasResourceId', _shadowAtlas.resourceId))
      ..add(IntProperty('shadowAtlasBuildCount', _shadowAtlas.buildCount))
      ..add(IntProperty('shadowAtlasPaintCount', _shadowAtlas.paintCount))
      ..add(
        DoubleProperty('shadowAtlasMinimumAmount', _shadowAtlas.minimumAmount),
      )
      ..add(
        DoubleProperty('shadowAtlasMaximumAmount', _shadowAtlas.maximumAmount),
      )
      ..add(IntProperty('shadowAtlasQueuedJobs', _ContourAtlasQueue.queuedJobs))
      ..add(IntProperty('shadowAtlasActiveJobs', _ContourAtlasQueue.activeJobs))
      ..add(
        IntProperty(
          'shadowAtlasTransientPixels',
          _ContourAtlasQueue.transientPixels,
        ),
      )
      ..add(
        IntProperty(
          'shadowAtlasSnapshotBytes',
          _ContourShadowAtlasSource.retainedBytes,
        ),
      )
      ..add(IntProperty('shadowCacheBuildCount', _shadowCache.buildCount))
      ..add(IntProperty('shadowPoolEntries', _ContourImagePool.entries))
      ..add(IntProperty('shadowPoolPending', _ContourImagePool.pending))
      ..add(IntProperty('shadowPoolPixels', _ContourImagePool.retainedPixels))
      ..add(IntProperty('shadowPoolBuildCount', _ContourImagePool.buildCount))
      ..add(IntProperty('shadowPoolReuseCount', _ContourImagePool.reuseCount))
      ..add(IntProperty('shadowResourceId', _shadowCache.resourceId))
      ..add(FlagProperty('shadowCacheReady', value: _shadowCache.ready, ifTrue: 'ready'))
      ..add(FlagProperty('compositeReady', value: _compositeBacking.ready, ifTrue: 'ready'))
      ..add(FlagProperty('compositePending', value: _compositeBacking.pending, ifTrue: 'pending'))
      ..add(FlagProperty('contourReady', value: _shape != null, ifTrue: 'ready'))
      ..add(
        FlagProperty(
          'generating',
          value:
              _running ||
              _nativeProofPending ||
              _pending ||
              _scheduled ||
              _shadowCache.generating ||
              _shadowAtlas.generating ||
              (_nativeStatus == 'checking' || _nativeStatus == 'waiting'),
          ifTrue: 'generating',
        ),
      );
  }

  void _paintMask(Canvas canvas, {Color color = const Color(0xFFFFFFFF)}) {
    final knownBox = _declaredSource?.knownBox;
    if (knownBox != null) {
      knownBox.paint(canvas, _fillPaint, _amount);
      return;
    }
    if (_nativeActive) {
      if (ContourNativeMaskPictureCache.instance.paintCached(
        canvas,
        sourceId: _nativeMaskSourceId!,
        amount: _amount,
        color: color,
      )) {
        return;
      }
      final source = _ContourNativeText.paragraph((child! as _RenderContourCapture).child)!;
      ContourNativeMaskPictureCache.instance.paint(
        canvas,
        sourceId: _nativeMaskSourceId!,
        amount: _amount,
        sourceBytes: _nativeMaskSourceBytes,
        color: color,
        paint: (target) {
          _nativeText.update(source, _amount, color: color);
          _nativeText.paint(target, _nativeOffset);
        },
      );
      return;
    }
    canvas.drawPath(_shape!, _fillPaint);
    if (_amount > 0) canvas.drawPath(_shape!, _strokePaint);
  }

  ui.Picture _recordAtlasMask(double amount) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final knownBox = _declaredSource?.knownBox;
    if (knownBox != null) {
      knownBox.paint(canvas, Paint()..color = const Color(0xFFFFFFFF), amount);
    } else if (_nativeActive) {
      final source = _ContourNativeText.paragraph(
        (child! as _RenderContourCapture).child,
      )!;
      _nativeText.update(source, amount);
      _nativeText.paint(canvas, _nativeOffset);
    } else {
      canvas.drawPath(_shape!, Paint()..color = const Color(0xFFFFFFFF));
      if (amount > 0) {
        canvas.drawPath(
          _shape!,
          Paint()
            ..color = const Color(0xFFFFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = amount * 2,
        );
      }
    }
    return recorder.endRecording();
  }

  void _paintShadows(Canvas canvas) {
    final bounds = _maskBounds;
    final knownBox = _declaredSource?.knownBox;
    final gaussian = _prepareBoxGaussian();
    final directPaints = knownBox == null
        ? null
        : (_knownBoxShadowPaints ??= [
            for (final shadow in _shadows)
              if (shadow.blurRadius > 0 && shadow.color.colorSpace == ui.ColorSpace.sRGB)
                Paint()
                  ..color = shadow.color
                  ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma)
              else
                null,
          ]);
    for (var index = 0; index < _shadows.length; index++) {
      final shadow = _shadows[index];
      if (shadow.color.a == 0) continue;
      if (gaussian && shadow.blurRadius > 0) {
        if (_boxGaussianShadow.paint(canvas, shadow)) continue;
      }
      final directPaint = directPaints?[index];
      if (knownBox != null && directPaint != null) {
        canvas
          ..save()
          ..translate(shadow.offset.dx, shadow.offset.dy);
        knownBox.paint(canvas, directPaint, _amount);
        _boxGaussianNativePaintCount++;
        canvas.restore();
        continue;
      }
      canvas
        ..save()
        ..translate(shadow.offset.dx, shadow.offset.dy)
        ..saveLayer(bounds.inflate(shadow.blurSigma * 3), _shadowPaints[index]);
      _paintMask(canvas);
      canvas
        ..restore()
        ..restore();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hasDecoration) {
      if (!_hasPresented) {
        _hasPresented = true;
        markNeedsSemanticsUpdate();
      }
      _decorationLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    _tryDeclaredGeometry();
    _tryWarmGeometry();
    if (_nativeActive) {
      final capture = child! as _RenderContourCapture;
      final source = _ContourNativeText.paragraph(capture.child);
      final translation = source?.getTransformTo(capture).getTranslation();
      final origin = translation == null ? Offset.zero : Offset(translation.x, translation.y);
      if (source is! RenderParagraph ||
          !_useNativeText ||
          (_ContourNativeText.signature(source), origin) != _nativeAcceptedSettings) {
        contentChanged();
      } else if (_nativeNeedsShadow) {
        _nativeNeedsShadow = false;
        _scheduleShadowCache();
      }
    }
    final recordedShape = _shape;
    final recordedRevision = _contentRevision;
    if (_shape == null) {
      final layer = (_decorationLayer.layer ??= _ContourPictureDecorationLayer())
        ..isCurrent = (() => false)
        ..canPresent = (() => _canPresent(recordedShape, recordedRevision))
        ..configure(picture: null, offset: offset, sourceIdentity: null, sourceRevision: recordedRevision);
      context.pushLayer(layer, super.paint, offset);
      return;
    }
    final composite = _compositeBacking;
    if (composite.ready && recordedShape != null) {
      final identity = composite.identity;
      final recorder = ui.PictureRecorder();
      composite.paint(Canvas(recorder));
      final layer = (_decorationLayer.layer ??= _ContourPictureDecorationLayer())
        ..isCurrent = (() {
          if (!composite.ready || !identical(composite.identity, identity) || _contentRevision != recordedRevision) {
            return false;
          }
          final capture = child;
          if (capture is! _RenderContourCapture || !composite.current(this, capture)) {
            contentChanged();
            markNeedsPaint();
            return false;
          }
          return true;
        })
        ..canPresent = (() => _canPresent(recordedShape, recordedRevision))
        ..configure(
          picture: recorder.endRecording(),
          offset: offset,
          sourceIdentity: identity,
          sourceRevision: recordedRevision,
        );
      context.pushLayer(layer, super.paint, offset);
      return;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bounds = _maskBounds;
    if (!_shadowAtlas.paint(canvas, _amount)) {
      if (_shadowCache.ready) {
        _shadowCache.paint(canvas);
      } else {
        _paintShadows(canvas);
      }
    }
    if (_color.a > 0) {
      if (_color.a == 1 &&
          (!_nativeActive ||
              const <Type>{Color, ColorSwatch<int>, MaterialColor, MaterialAccentColor}.contains(_color.runtimeType))) {
        _fillPaint.color = _color;
        _strokePaint.color = _color;
        _paintMask(canvas, color: _color);
        _fillPaint.color = const Color(0xFFFFFFFF);
        _strokePaint.color = const Color(0xFFFFFFFF);
      } else {
        canvas.saveLayer(bounds, _colorPaint);
        _paintMask(canvas);
        canvas.restore();
      }
    }
    final layer = (_decorationLayer.layer ??= _ContourPictureDecorationLayer())
      ..isCurrent = (() => identical(_shape, recordedShape) && _contentRevision == recordedRevision)
      ..canPresent = (() => _canPresent(recordedShape, recordedRevision))
      ..configure(
        picture: recorder.endRecording(),
        offset: offset,
        sourceIdentity: recordedShape,
        sourceRevision: recordedRevision,
      );
    context.pushLayer(layer, super.paint, offset);
  }
}
