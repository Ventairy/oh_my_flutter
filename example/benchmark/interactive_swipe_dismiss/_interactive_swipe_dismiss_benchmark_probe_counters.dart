part of 'interactive_swipe_dismiss_benchmark.dart';

final class _InteractiveSwipeDismissBenchmarkProbeCounters {
  static int builds = 0;
  static int layouts = 0;
  static int paints = 0;

  static ({int builds, int layouts, int paints}) get snapshot => (
    builds: builds,
    layouts: layouts,
    paints: paints,
  );
}
