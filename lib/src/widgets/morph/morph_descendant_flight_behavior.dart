/// Strategies for representing a `MorphDescendant` during a Morph flight.
enum MorphDescendantFlightBehavior {
  /// Keeps a live in-flight subtree that responds to the changing flight size.
  ///
  /// This is the behavior ordinary Morph content already has. During a flight,
  /// Flutter may mount an additional copy of the subtree. Prefer [snapshot] for
  /// content that must have only one mounted owner, such as editable fields,
  /// scrollables with a shared controller, and subtrees containing GlobalKeys.
  live,

  /// Shows a fixed image of the selected endpoint without mounting another
  /// copy of the subtree.
  ///
  /// The source image is shown before the nearest Morph's `switchThreshold` and
  /// the destination image afterward. Each image keeps its endpoint dimensions
  /// instead of laying out against the changing flight size. The resting
  /// subtree keeps its mounted state, focus, selection, and scroll position.
  ///
  /// Content that Flutter cannot capture as an image, such as a platform view,
  /// is empty during the flight. Use [hide] when empty flight content is the
  /// intended result for every platform.
  snapshot,

  /// Keeps the selected endpoint's space empty during the flight.
  ///
  /// The reserved size changes from the source size to the destination size at
  /// the nearest Morph's `switchThreshold`. The resting subtree remains
  /// mounted normally.
  hide;

  /// Whether this behavior keeps a live copy in the flight.
  bool get isLive => switch (this) {
    live => true,
    snapshot || hide => false,
  };

  /// Whether this behavior paints captured endpoint images in the flight.
  bool get usesSnapshot => switch (this) {
    live || hide => false,
    snapshot => true,
  };
}
