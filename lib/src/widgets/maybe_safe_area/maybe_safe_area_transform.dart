part of 'maybe_safe_area.dart';

/// Keeps safe-area placement attached to a surface while that surface moves.
///
/// Implement this on a [RenderObject] that moves a complete surface, such as a
/// page transition, when its descendants should avoid the unsafe edges of the
/// surface's resting position. Descendant movement within that surface still
/// participates in avoidance. Ordinary painting, hit testing, and semantics
/// continue to use [RenderObject.applyPaintTransform].
///
/// See the [MaybeSafeArea guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/maybe_safe_area.md#moving-complete-surfaces).
abstract interface class MaybeSafeAreaTransform implements RenderObject {
  /// Whether descendants should use the surface's resting safe-area geometry.
  ///
  /// When false, calculations use the ordinary paint transform.
  /// Request painting and semantics updates when changing this value or the
  /// resting transform.
  bool get usesRestingSafeAreaGeometry;

  /// Adds [child]'s resting position to the accumulated [transform].
  ///
  /// Called only while [usesRestingSafeAreaGeometry] is true. Like
  /// [RenderObject.applyPaintTransform], this maps child coordinates into this
  /// render object's coordinates. Retain positioning and transforms that belong
  /// to the resting surface, omitting only its movement as a whole.
  void applyRestingPaintTransform(RenderObject child, Matrix4 transform);
}
