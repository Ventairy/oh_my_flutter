part of 'skeleton.dart';

class _SkeletonTransitionHost extends StatefulWidget {
  const new({required this.skeleton});

  final Skeleton skeleton;

  @override
  State<_SkeletonTransitionHost> createState() => _SkeletonState();
}

class _SkeletonState extends State<_SkeletonTransitionHost> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _curvedAnimation;
  Curve? _animationCurve;
  final GlobalKey _visualKey = GlobalKey(debugLabel: 'skeleton_visual');
  final GlobalKey _childKey = GlobalKey(debugLabel: 'skeleton_child');
  ui.Image? _outgoingImage;
  Size? _outgoingSize;
  bool _customActive = false;

  @override
  void initState() {
    super.initState();
    assert(widget.skeleton.transition?._debugValidateDuration() ?? true, 'transition duration must be valid.');
    if (widget.skeleton.transition != null) _ensureController(initialEnabled: widget.skeleton.enabled);
  }

  AnimationController _ensureController({required bool initialEnabled}) => _controller ??= AnimationController(
    vsync: this,
    value: initialEnabled ? 0 : 1,
  )..addStatusListener(_onStatusChanged);

  Animation<double> _animationFor(Curve curve, AnimationController controller) {
    if (_animationCurve == curve && _curvedAnimation != null) return _curvedAnimation!;
    _animationCurve = curve;
    return _curvedAnimation = CurveTween(curve: curve).animate(controller);
  }

  @override
  void didUpdateWidget(covariant _SkeletonTransitionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.skeleton.transition?._debugValidateDuration() ?? true, 'transition duration must be valid.');
    if (oldWidget.skeleton.enabled == widget.skeleton.enabled) {
      if ((oldWidget.skeleton.transition?._builder == null) != (widget.skeleton.transition?._builder == null) ||
          (oldWidget.skeleton.transition == null) != (widget.skeleton.transition == null)) {
        _clearOutgoing();
        _customActive = false;
        _controller?.value = widget.skeleton.enabled ? 0 : 1;
      }
      return;
    }

    final transition = widget.skeleton.transition;
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (transition == null || transition.duration == Duration.zero || disableAnimations) {
      _clearOutgoing();
      _customActive = false;
      _controller?.value = widget.skeleton.enabled ? 0 : 1;
      return;
    }

    final controller = _ensureController(initialEnabled: oldWidget.skeleton.enabled);

    if (transition._builder != null) {
      final boundary = _visualKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary ||
          boundary.debugNeedsPaint ||
          !boundary.hasSize ||
          boundary.size.isEmpty) {
        _clearOutgoing();
        _customActive = false;
        controller.value = widget.skeleton.enabled ? 0 : 1;
        return;
      }
      final outgoing = boundary.toImageSync(pixelRatio: MediaQuery.devicePixelRatioOf(context));
      _clearOutgoing();
      _outgoingImage = outgoing;
      _outgoingSize = boundary.size;
      _customActive = true;
      controller
        ..duration = transition.duration
        ..value = 0
        ..forward();
      return;
    }

    _clearOutgoing();
    _customActive = false;
    controller.duration = transition.duration;
    if (widget.skeleton.enabled) {
      controller.reverse();
    } else {
      controller.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) return;
    _clearOutgoing();
    _customActive = false;
    _controller?.value = widget.skeleton.enabled ? 0 : 1;
  }

  void _onStatusChanged(AnimationStatus status) {
    if (!_customActive || !status.isCompleted) return;
    setState(() {
      _customActive = false;
      _clearOutgoing();
    });
  }

  void _clearOutgoing() {
    final image = _outgoingImage;
    _outgoingImage = null;
    _outgoingSize = null;
    if (image != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
    }
  }

  @override
  void dispose() {
    _controller
      ?..removeStatusListener(_onStatusChanged)
      ..dispose();
    _outgoingImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final transition = widget.skeleton.transition!;
    final controller = _ensureController(initialEnabled: widget.skeleton.enabled);
    final transitionEnabled = transition.duration > Duration.zero && !disableAnimations;
    var visual = widget.skeleton._buildAppearance(
      context,
      blend: transitionEnabled && transition._builder == null ? _animationFor(transition.curve, controller) : null,
      child: KeyedSubtree(key: _childKey, child: widget.skeleton.child),
    );

    if (transition._builder != null) {
      final image = _outgoingImage;
      final size = _outgoingSize;
      if (_customActive && image != null && size != null && transitionEnabled) {
        final outgoing = ExcludeSemantics(
          child: IgnorePointer(
            child: SizedBox.fromSize(
              size: size,
              child: RawImage(image: image, fit: BoxFit.fill),
            ),
          ),
        );
        visual = transition._builder!(
          outgoing,
          visual,
          _animationFor(transition.curve, controller),
        );
      }
      return RepaintBoundary(key: _visualKey, child: visual);
    }
    return visual;
  }
}
