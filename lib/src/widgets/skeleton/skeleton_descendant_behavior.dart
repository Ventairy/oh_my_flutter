part of 'skeleton.dart';

/// Controls how an annotated subtree appears inside an enabled [Skeleton].
enum SkeletonDescendantBehavior {
  /// Paints the first visible descendant as a bone and omits everything below it.
  ///
  /// When the subtree paints no visible content, its layout bounds become a
  /// rectangular bone using [SkeletonStyle.radius].
  paintAsBone,

  /// Skips the subtree's first visible painted level and skeletonizes its children.
  ///
  /// Nested annotations can defer additional levels independently.
  deferToChildren,

  /// Omits the entire subtree from the skeleton while preserving its layout space.
  hide,
}
