part of 'morph.dart';

class _MorphSwitchTransition extends StatefulWidget {
  const _MorphSwitchTransition({
    required this.progress,
    required this.transitionBuilder,
    required this.child,
    required this.capturedThemes,
    required this.mediaQueryData,
  });

  final double progress;
  final AnimatedSwitcherTransitionBuilder? transitionBuilder;
  final Widget child;
  final CapturedThemes? capturedThemes;
  final MediaQueryData? mediaQueryData;

  @override
  State<_MorphSwitchTransition> createState() => _MorphSwitchTransitionState();
}

class _MorphSwitchTransitionState extends State<_MorphSwitchTransition> {
  late final _MorphTransitionAnimation _animation = _MorphTransitionAnimation(widget.progress);
  late Widget _transition = _buildTransition();

  @override
  void didUpdateWidget(
    covariant _MorphSwitchTransition oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.child, widget.child) ||
        !identical(
          oldWidget.transitionBuilder,
          widget.transitionBuilder,
        ) ||
        !identical(oldWidget.capturedThemes, widget.capturedThemes) ||
        (!identical(oldWidget.mediaQueryData, widget.mediaQueryData) &&
            oldWidget.mediaQueryData != widget.mediaQueryData)) {
      _transition = _buildTransition();
    }
    _animation.value = widget.progress;
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _transition;

  Widget _buildTransition() {
    final transitionBuilder = widget.transitionBuilder;
    var result = transitionBuilder == null
        ? RepaintBoundary(child: widget.child)
        : transitionBuilder(widget.child, _animation);
    result = widget.capturedThemes?.wrap(result) ?? result;
    final mediaQueryData = widget.mediaQueryData;
    if (mediaQueryData != null) {
      result = MediaQuery(data: mediaQueryData, child: result);
    }
    return result;
  }
}
