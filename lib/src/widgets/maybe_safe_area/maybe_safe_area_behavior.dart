part of 'maybe_safe_area.dart';

/// How a [MaybeSafeArea] responds when its painted position changes.
enum MaybeSafeAreaBehavior {
  /// Keeps avoidance current while the child or its ancestors move.
  ///
  /// Use this for controls that independently scroll, animate, or otherwise
  /// move toward and away from unsafe view edges.
  live,

  /// Carries the initially resolved avoidance with the moving child.
  ///
  /// Use this when an enclosing surface moves as a unit and the child should
  /// keep the same position within that surface. Avoidance is resolved again
  /// when the view geometry, enabled edges, or child size changes.
  preserve,
}
