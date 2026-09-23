part of 'morph.dart';

/// Chooses how a `MorphDescendant` appears during its Morph flight.
@immutable
sealed class MorphDescendantFlightBehavior {
  const new();

  /// Keeps a live in-flight subtree that responds to the changing flight size.
  ///
  /// Flutter may mount an additional copy of the subtree during the flight.
  /// Prefer `snapshot` for editable fields, shared scroll controllers, and
  /// subtrees containing GlobalKeys that must have only one mounted owner.
  const factory live() = _MorphDescendantLiveFlightBehavior;

  /// Shows an image of the selected endpoint without mounting another copy.
  ///
  /// Automatic flights select the source image before `childSwitchAt` and the
  /// destination image afterward. Each image keeps its endpoint dimensions.
  /// The resting subtree keeps its mounted state, focus, selection, and scroll
  /// position. A watched destination can refresh its image during the flight.
  ///
  /// Supply `changes` when independent visual changes inside the descendant
  /// should appear in a watched flight. The notifier must signal every such
  /// change; unsignaled changes remain absent until live content takes over.
  /// Layout changes and updates to the descendant child remain automatic.
  /// Without `changes`, nested repaint boundaries may be captured continuously.
  ///
  /// Content that Flutter cannot capture as an image, such as a platform view,
  /// is empty during the flight. Use `hide` when that is the intended result.
  const factory snapshot({Listenable? changes}) = _MorphDescendantSnapshotFlightBehavior;

  /// Keeps the selected endpoint's space empty during the flight.
  ///
  /// Automatic flights change the reserved size at `childSwitchAt`. The
  /// resting subtree remains mounted normally.
  const factory hide() = _MorphDescendantHideFlightBehavior;

  /// Whether the flight mounts a live copy of the descendant.
  bool get isLive => this is _MorphDescendantLiveFlightBehavior;

  /// Whether the flight paints captured images of the descendant.
  bool get usesSnapshot => this is _MorphDescendantSnapshotFlightBehavior;

  Listenable? get _snapshotChanges => switch (this) {
    _MorphDescendantSnapshotFlightBehavior(:final changes) => changes,
    _MorphDescendantLiveFlightBehavior() || _MorphDescendantHideFlightBehavior() => null,
  };

  // The notifier changes refresh timing, not how two descendants match.
  @override
  bool operator ==(Object other) => other is MorphDescendantFlightBehavior && other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}
