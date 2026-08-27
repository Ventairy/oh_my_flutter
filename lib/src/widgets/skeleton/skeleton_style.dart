part of 'skeleton.dart';

/// The visual configuration applied to a [Skeleton].
@immutable
class SkeletonStyle {
  /// Creates a skeleton style with a neutral gray resting color.
  const SkeletonStyle({
    this.color = const Color(0xFFE0E0E0),
    this.effect,
    this.radius = const Radius.circular(4),
  });

  /// The fill color used for skeleton bones.
  final Color color;

  /// The optional effect painted across the skeleton bones.
  final SkeletonEffect? effect;

  /// The corner radius applied to rectangular skeleton bones.
  ///
  /// This includes text lines, images, and rectangular or rounded-rectangular
  /// painted leaves. Circular and freeform shapes keep their original geometry.
  final Radius radius;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SkeletonStyle && other.color == color && other.effect == effect && other.radius == radius;
  }

  @override
  int get hashCode => Object.hash(color, effect, radius);
}
