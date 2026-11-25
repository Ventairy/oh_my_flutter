part of '../../motion.dart';

class _MotionDisintegrationHost extends StatefulWidget {
  const new({
    required this.effects,
    required this.controller,
    required this.startup,
    required this.interactive,
    required this.presentation,
    required this.child,
    this.progress,
    this.stagger = Duration.zero,
    this.characterCount = 0,
    super.key,
  });

  final List<MotionEffect> effects;
  final MotionController? controller;
  final MotionStartup startup;
  final bool interactive;
  final MotionRenderPresentation presentation;
  final Widget child;
  final Animation<double>? progress;
  final Duration stagger;
  final int characterCount;

  @override
  State<_MotionDisintegrationHost> createState() => _MotionDisintegrationHostState();
}

class _MotionDisintegrationHostState extends State<_MotionDisintegrationHost> with WidgetsBindingObserver {
  static int _nextInstance = 0;
  final int _instance = ++_nextInstance;
  final GlobalKey _captureKey = GlobalKey();
  final _sourceTransform = MotionEffectTransform._();
  List<_MotionApplication> _applications = [];
  _MotionDisintegrationFrame? _frame;
  bool _sourceReplaced = false;
  bool _rebuildScheduled = false;
  bool _tickersEnabled = true;
  int _preparation = 0;
  void Function(bool)? _finishPreparation;
  bool _drivenPreparationStarted = false;
  bool _drivenReady = false;
  late double _maximumBlurOutset;
  late bool _capturesBlurredSource;

  void _prepareDriven() {
    _finishPreparation?.call(true);
    final finish = _finishPreparation = TransitionPreparationScope.hold(context);
    _drivenReady = false;
    final preparing = _prepare();
    final generation = _preparation;
    unawaited(
      preparing.then((_) {
        if (!mounted || generation != _preparation) return;
        _drivenReady = _frame != null;
        finish?.call(_drivenReady);
        _finishPreparation = null;
        _onFrame();
      }),
    );
  }

  void _updateBlurOutset() {
    var sigma = 0.0;
    var earlierEffectCanBlur = false;
    _capturesBlurredSource = false;
    final sample = MotionEffectTransform._();
    for (final effect in widget.effects) {
      final source = effect is _TextMotionEffect ? effect.effect : effect;
      final bounds = _MotionRenderEffect._sampleBounds(source, isLinear: identical(source.curve, Curves.linear));
      if (sigma > 0 || bounds.maximumBlurSigma > 0) {
        for (var index = 0; index <= _MotionRenderEffect._boundsSampleCount; index++) {
          sample._reset();
          source.apply(source.curve.transform(index / _MotionRenderEffect._boundsSampleCount), sample);
          if (!sample._hasDisintegration) break;
          // An off-sample declared peak can also be conditional on progress.
          if (earlierEffectCanBlur ||
              (source.bounds?.maximumBlurSigma ?? 0) > 0 ||
              sample._operations!.take(sample._operationCount).any((operation) => operation.callsBlur)) {
            _capturesBlurredSource = true;
            break;
          }
        }
      }
      earlierEffectCanBlur = earlierEffectCanBlur || bounds.maximumBlurSigma > 0;
      sigma = _MotionBlur.combine(sigma * math.max(1, bounds.maximumScale), bounds.maximumBlurSigma);
    }
    _maximumBlurOutset = _MotionBlur.outset(sigma);
  }

  void _listen(List<_MotionApplication> applications) {
    if (listEquals(_applications, applications)) return;
    for (final application in _applications) {
      application.animation
        ..removeListener(_onFrame)
        ..removeStatusListener(_onAnimationStatus);
    }
    _applications = applications;
    for (final application in applications) {
      application.animation
        ..addListener(_onFrame)
        ..addStatusListener(_onAnimationStatus);
    }
  }

  void _rebuild() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase != .persistentCallbacks) {
      setState(() {});
      return;
    }
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _updateSourceTransform() {
    _sourceTransform._reset();
    for (final application in _applications) {
      application.effect.apply(application.animation.value, _sourceTransform);
    }
    _sourceTransform._finishOperations();
  }

  bool get _fullyDisintegrated {
    for (var index = 0; index < _sourceTransform._operationCount; index++) {
      final operation = _sourceTransform._operations![index];
      if (operation.kind == .disintegrate && operation.progress >= 1) return true;
    }
    return false;
  }

  void _releaseFrame({bool outputRemoved = false}) {
    _frame?.dispose(outputRemoved: outputRemoved);
    _frame = null;
  }

  void _onAnimationStatus(AnimationStatus status) => _onFrame();

  void _onFrame() {
    final frame = _frame;
    if (!mounted || frame == null) return;
    if (widget.progress case final progress?) {
      if (!_drivenReady) return;
      final wasComplete = _fullyDisintegrated;
      _updateSourceTransform();
      final replace = progress.value > 0 || progress.status == .forward;
      if (_sourceReplaced != replace || wasComplete != _fullyDisintegrated) {
        _sourceReplaced = replace;
        _rebuild();
      }
      frame.update(tickersEnabled: _tickersEnabled, onNativeFailure: _rebuild);
      return;
    }
    final running = _applications.any((application) => application.animation.status == .forward);
    if (running && !_sourceReplaced) {
      _sourceReplaced = true;
      _rebuild();
    }
    if (widget.progress == null &&
        !running &&
        _applications.every((application) => application.animation.status == .completed)) {
      _updateSourceTransform();
      if (_fullyDisintegrated) {
        _releaseFrame(outputRemoved: true);
        _rebuild();
        return;
      }
    }
    frame.update(tickersEnabled: _tickersEnabled, onNativeFailure: _rebuild);
  }

  Future<void> _prepare() async {
    final preparation = ++_preparation;
    _releaseFrame();
    _sourceReplaced = false;
    _rebuild();
    _updateSourceTransform();
    if (widget.progress == null && _fullyDisintegrated) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || preparation != _preparation) return;
    final boundary = _captureKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || boundary.size.isEmpty) return;

    _MotionDisintegrationSource? source;
    _MotionDisintegrationFrame? prepared;
    try {
      final devicePixelRatio = View.of(context).devicePixelRatio;
      source = await _MotionDisintegrationSource.capture(
        boundary,
        isText: widget.characterCount != 0,
        devicePixelRatio: devicePixelRatio,
        effects: widget.effects,
        blurOutset: _maximumBlurOutset,
        capturesBlurredSource: _capturesBlurredSource,
      );
      prepared = _MotionDisintegrationFrame(
        source: source,
        instance: _instance,
        applications: _applications,
        stagger: widget.stagger,
        capturesBlurredSource: _capturesBlurredSource,
        devicePixelRatio: devicePixelRatio,
        maximumBlurOutset: _maximumBlurOutset,
      );
      if (!mounted || preparation != _preparation) {
        prepared.dispose();
        return;
      }
      await prepared.prepare(isText: widget.characterCount != 0);
      if (!mounted || preparation != _preparation) {
        prepared.dispose();
        return;
      }
      _frame = prepared;
      await prepared.waitUntilReady();
    } on Object catch (error, stackTrace) {
      prepared?.dispose();
      if (prepared == null) source?.image.dispose();
      if (!mounted || preparation != _preparation) return;
      _frame = null;
      _rebuild();
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'oh_my_flutter',
          context: ErrorDescription('while preparing captured motion'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateBlurOutset();
  }

  @override
  void didUpdateWidget(_MotionDisintegrationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.effects, widget.effects)) _updateBlurOutset();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    if (_tickersEnabled == enabled) return;
    _tickersEnabled = enabled;
    if (!enabled) {
      unawaited(_frame?.pause());
      return;
    }
    _onFrame();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == .resumed && widget.progress != null && !_drivenPreparationStarted) {
      _rebuild();
    }
    if (state != .paused) return;
    _drivenPreparationStarted = false;
    _drivenReady = false;
    _finishPreparation?.call(false);
    _finishPreparation = null;
    _preparation++;
    _releaseFrame();
    _MotionDisintegrationFrame.release(_instance);
    _rebuild();
  }

  @override
  void dispose() {
    _preparation++;
    WidgetsBinding.instance.removeObserver(this);
    _listen(const []);
    _releaseFrame();
    _MotionDisintegrationFrame.release(_instance);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.progress case final animation?) {
      final applications = [(effect: widget.effects.single, animation: animation)];
      if (!_drivenPreparationStarted || !listEquals(applications, _applications)) {
        _listen(applications);
        _drivenPreparationStarted = true;
        _prepareDriven();
      }
      return _buildPresentation(applications);
    }
    return _MotionAnimationHost(
      controller: widget.controller,
      effects: widget.effects,
      startup: widget.startup,
      interactive: widget.interactive,
      preparePlayback: _prepare,
      transitionBuilder: _buildPresentation,
    );
  }

  Widget _buildPresentation(List<_MotionApplication> applications) {
    _listen(applications);
    _updateSourceTransform();
    final frame = _frame;
    return Stack(
      clipBehavior: .none,
      fit: .passthrough,
      children: [
        _buildSource(),
        if (frame != null && _sourceReplaced && !_fullyDisintegrated)
          Positioned.fromRect(
            rect: frame.outputBounds,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  key: const ValueKey('motion_render_surface'),
                  child: _buildParticleOutput(frame),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildParticleOutput(_MotionDisintegrationFrame frame) {
    final output = frame.usesNative
        ? frame.buildNativeOutput(devicePixelRatio: View.of(context).devicePixelRatio)
        : CustomPaint(key: ObjectKey(frame), painter: frame.painter);
    if (frame.usesNativeGaussian ||
        widget.characterCount != 0 ||
        frame.painter.capturesBlurredSource ||
        _maximumBlurOutset == 0) {
      return output;
    }
    return _MotionParticleBlur(applications: _applications, child: output);
  }

  Widget _buildSource() {
    final hidden =
        widget.presentation == .replace && (_sourceReplaced || (widget.progress == null && _fullyDisintegrated));
    final matrix = Matrix4.identity();
    var opacity = 1.0;
    if (!_sourceReplaced) {
      for (var index = 0; index < _sourceTransform._operationCount; index++) {
        final operation = _sourceTransform._operations![index];
        if (operation.kind != .transform) continue;
        final a = operation.scale * operation.cosine;
        final b = operation.scale * operation.sine;
        final previousA = matrix.storage[0];
        final previousB = matrix.storage[1];
        final previousX = matrix.storage[12];
        final previousY = matrix.storage[13];
        matrix.storage[0] = a * previousA - b * previousB;
        matrix.storage[1] = b * previousA + a * previousB;
        matrix.storage[4] = -matrix.storage[1];
        matrix.storage[5] = matrix.storage[0];
        matrix.storage[12] = a * previousX - b * previousY + operation.x;
        matrix.storage[13] = b * previousX + a * previousY + operation.y;
        opacity *= operation.opacity.clamp(0.0, 1.0);
      }
    }
    final previewHasBlur = !_sourceReplaced && !hidden && _maximumBlurOutset > 0;
    final child = widget.child;
    final preview = previewHasBlur && child is _TextMotionTransition
        ? child.withApplications(
            _TextMotionEffect.applicationsFor(_applications),
            previewScale: math.sqrt(matrix.storage[0] * matrix.storage[0] + matrix.storage[1] * matrix.storage[1]),
          )
        : child;
    final source = Transform(
      alignment: Alignment.center,
      transform: matrix,
      child: Opacity(
        alwaysIncludeSemantics: true,
        opacity: hidden ? 0 : opacity,
        child: RepaintBoundary(key: _captureKey, child: preview),
      ),
    );
    // An overlay's live source stays sharp once the captured particles take over.
    if (widget.characterCount != 0 || !previewHasBlur) return source;
    return _MotionParticleBlur(applications: _applications, preview: true, child: source);
  }
}
