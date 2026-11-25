part of 'snap_list.dart';

class _SnapListRemoval extends StatefulWidget {
  const new({
    required this.surfaces,
    required this.builder,
    required this.duration,
    required this.onDone,
    super.key,
  });

  final List<Positioned> surfaces;
  final Widget Function(BuildContext, Animation<double>, Widget) builder;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_SnapListRemoval> createState() => _SnapListRemovalState();
}

class _SnapListRemovalState extends State<_SnapListRemoval> with SingleTickerProviderStateMixin {
  late final _animationController = AnimationController(vsync: this, duration: widget.duration);
  late final _progress = LinearTransitionProgress(_animationController.view, widget.duration);
  void _start(bool ready) {
    if (!ready) {
      widget.onDone();
      return;
    }
    unawaited(
      _animationController.forward().then<void>((_) {
        if (mounted) widget.onDone();
      }),
    );
  }

  @override
  Widget build(BuildContext context) => PreparedTransition(
    onReady: _start,
    child: IgnorePointer(
      child: ExcludeFocus(
        child: ExcludeSemantics(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final surface in widget.surfaces)
                Positioned(
                  left: surface.left,
                  top: surface.top,
                  width: surface.width,
                  height: surface.height,
                  child: Builder(
                    builder: (context) => widget.builder(context, _progress, surface.child),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
