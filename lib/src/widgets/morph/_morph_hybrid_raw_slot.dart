part of 'morph.dart';

class _MorphHybridRawSlot extends StatefulWidget {
  const _MorphHybridRawSlot({
    required this.animation,
    required this.plan,
    required this.transitionBuilder,
    this.clipToSlot = true,
    this.alignToTopLeft = true,
    this.repaintChild = true,
  });

  final Animation<double> animation;
  final _MorphHybridRawSlotPlan plan;
  final AnimatedSwitcherTransitionBuilder? transitionBuilder;
  final bool clipToSlot;
  final bool alignToTopLeft;
  final bool repaintChild;

  @override
  State<_MorphHybridRawSlot> createState() => _MorphHybridRawSlotState();
}

class _MorphHybridRawSlotState extends State<_MorphHybridRawSlot> {
  late MorphChildProperties? _selectedProperties = widget.plan.rawPropertiesAt(widget.animation.value);
  _MorphTransitionAnimation? _transitionAnimation;

  @override
  void initState() {
    super.initState();
    widget.animation.addListener(_handleAnimationChanged);
  }

  @override
  void didUpdateWidget(covariant _MorphHybridRawSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.animation, widget.animation)) {
      oldWidget.animation.removeListener(_handleAnimationChanged);
      widget.animation.addListener(_handleAnimationChanged);
    }
    final selected = widget.plan.rawPropertiesAt(widget.animation.value);
    _syncTransitionAnimation();
    if (!identical(selected, _selectedProperties) ||
        !identical(oldWidget.transitionBuilder, widget.transitionBuilder)) {
      _selectedProperties = selected;
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_handleAnimationChanged);
    _transitionAnimation?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final properties = _selectedProperties;
    Widget child;
    if (properties == null) {
      child = const SizedBox.shrink();
    } else {
      final transitionBuilder = widget.transitionBuilder;
      child = transitionBuilder == null
          ? widget.repaintChild
                ? RepaintBoundary(child: properties.widget)
                : properties.widget
          : transitionBuilder(
              properties.widget,
              _transitionAnimation ??= _MorphTransitionAnimation(
                widget.plan.rawTransitionProgressAt(widget.animation.value),
              ),
            );
      child = properties._capturedThemes?.wrap(child) ?? child;
      final mediaQueryData = properties._mediaQueryData;
      if (mediaQueryData != null) {
        child = MediaQuery(data: mediaQueryData, child: child);
      }
      final explicitSize = properties.explicitSize;
      if (explicitSize != null) {
        child = SizedBox.fromSize(size: explicitSize, child: child);
      }
      if (properties.padding != EdgeInsets.zero) {
        child = Padding(padding: properties.padding, child: child);
      }
    }
    if (!widget.alignToTopLeft) {
      return widget.clipToSlot ? ClipRect(child: child) : child;
    }
    final aligned = Align(
      alignment: Alignment.topLeft,
      child: child,
    );
    return widget.clipToSlot ? ClipRect(child: aligned) : aligned;
  }

  void _handleAnimationChanged() {
    final progress = widget.animation.value;
    final transitionAnimation = _transitionAnimation;
    if (transitionAnimation != null) {
      transitionAnimation.value = widget.plan.rawTransitionProgressAt(progress);
    }
    final selected = widget.plan.rawPropertiesAt(progress);
    if (identical(selected, _selectedProperties)) return;
    setState(() => _selectedProperties = selected);
  }

  void _syncTransitionAnimation() {
    if (widget.transitionBuilder == null) {
      _transitionAnimation?.dispose();
      _transitionAnimation = null;
      return;
    }
    final value = widget.plan.rawTransitionProgressAt(widget.animation.value);
    final transitionAnimation = _transitionAnimation;
    if (transitionAnimation == null) {
      _transitionAnimation = _MorphTransitionAnimation(value);
      return;
    }
    transitionAnimation.value = value;
  }
}
