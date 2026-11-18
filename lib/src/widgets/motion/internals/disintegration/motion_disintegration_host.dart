part of '../../motion.dart';

class _MotionDisintegrationHost extends StatefulWidget {
  const new({
    required this.effects,
    required this.controller,
    required this.startup,
    required this.interactive,
    required this.presentation,
    required this.child,
    this.stagger = Duration.zero,
    this.characterCount = 0,
  });

  final List<MotionEffect> effects;
  final MotionController? controller;
  final MotionStartup startup;
  final bool interactive;
  final MotionRenderPresentation presentation;
  final Widget child;
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

  void _releaseFrame() {
    _frame?.dispose();
    _frame = null;
  }

  void _onAnimationStatus(AnimationStatus status) => _onFrame();

  void _onFrame() {
    final frame = _frame;
    if (!mounted || frame == null) return;
    final running = _applications.any((application) => application.animation.status == .forward);
    if (running && !_sourceReplaced) {
      _sourceReplaced = true;
      _rebuild();
    }
    if (!running && _applications.every((application) => application.animation.status == .completed)) {
      _updateSourceTransform();
      if (_fullyDisintegrated) {
        _releaseFrame();
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
    if (_fullyDisintegrated) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || preparation != _preparation) return;
    final boundary = _captureKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || boundary.size.isEmpty) return;

    _MotionDisintegrationSource? source;
    _MotionDisintegrationFrame? prepared;
    try {
      source = await _MotionDisintegrationSource.capture(
        boundary,
        isText: widget.characterCount != 0,
        devicePixelRatio: View.of(context).devicePixelRatio,
        effects: widget.effects,
      );
      prepared = _MotionDisintegrationFrame(
        source: source,
        instance: _instance,
        applications: _applications,
        stagger: widget.stagger,
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
    if (state != .paused) return;
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
    return _MotionAnimationHost(
      controller: widget.controller,
      effects: widget.effects,
      startup: widget.startup,
      interactive: widget.interactive,
      preparePlayback: _prepare,
      transitionBuilder: (applications) {
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
                      child: frame.usesNative
                          ? frame.buildNativeOutput(devicePixelRatio: View.of(context).devicePixelRatio)
                          : CustomPaint(key: ObjectKey(frame), painter: frame.painter),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSource() {
    final hidden = widget.presentation == .replace && (_fullyDisintegrated || _sourceReplaced);
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
    return Transform(
      alignment: Alignment.center,
      transform: matrix,
      child: Opacity(
        alwaysIncludeSemantics: true,
        opacity: hidden ? 0 : opacity,
        child: RepaintBoundary(key: _captureKey, child: widget.child),
      ),
    );
  }
}
