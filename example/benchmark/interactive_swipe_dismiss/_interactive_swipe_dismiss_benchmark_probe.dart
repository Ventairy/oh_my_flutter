part of 'interactive_swipe_dismiss_benchmark.dart';

class _InteractiveSwipeDismissBenchmarkProbe extends StatelessWidget {
  const _InteractiveSwipeDismissBenchmarkProbe({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    _InteractiveSwipeDismissBenchmarkProbeCounters.builds += 1;
    return _InteractiveSwipeDismissBenchmarkProbeRenderObjectWidget(
      child: child,
    );
  }
}
