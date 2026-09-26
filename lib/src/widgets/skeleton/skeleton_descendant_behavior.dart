part of 'skeleton.dart';

/// Controls how an annotated subtree appears inside an enabled [Skeleton].
///
/// Choose [SkeletonDescendantBehavior.paintAsBone] to show one loading shape,
/// [SkeletonDescendantBehavior.deferToChildren] to show shapes from deeper
/// content, or [SkeletonDescendantBehavior.hide] to leave the space empty.
sealed class SkeletonDescendantBehavior {
  const new _();

  /// Shows the subtree as one bone.
  ///
  /// Without [builder], the first visible painted descendant supplies the
  /// bone's shape. If nothing paints, the annotated child's bounds supply a
  /// rectangular bone using [SkeletonStyle.shape].
  ///
  /// With [builder], its widget replaces this branch's loading appearance and
  /// uses the annotated child's size. The widget paints as supplied; the
  /// enclosing [SkeletonStyle] does not change its appearance.
  const factory paintAsBone({WidgetBuilder? builder}) = _SkeletonPaintAsBoneBehavior;

  /// Skips the subtree's first visible painted level and shows bones below it.
  ///
  /// Nested annotations can defer additional levels independently.
  const factory deferToChildren() = _SkeletonDeferToChildrenBehavior;

  /// Leaves the subtree's layout space empty while the skeleton is enabled.
  const factory hide() = _SkeletonHideBehavior;
}
