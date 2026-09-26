part of 'skeleton.dart';

/// The visual configuration applied to a [Skeleton].
@immutable
class SkeletonStyle {
  /// Creates a skeleton style with a neutral gray resting color.
  const new({
    this.color = const Color(0xFFE0E0E0),
    this.effect,
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
  });

  /// The fill color used for skeleton bones.
  final Color color;

  /// The optional effect painted across the skeleton bones.
  final SkeletonEffect? effect;

  /// The shape applied to rectangular skeleton bones.
  ///
  /// This includes text lines, images, and rectangular or rounded-rectangular
  /// painted leaves. The outer path is filled without painting a border stroke.
  /// Circular and freeform shapes keep their original geometry.
  final ShapeBorder shape;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SkeletonStyle && other.color == color && other.effect == effect && other.shape == shape;
  }

  @override
  int get hashCode => Object.hash(color, effect, shape);
}
