part of 'skeleton.dart';

/// Customizes how one subtree is represented inside an enabled [Skeleton].
///
/// The annotation has no visible effect outside an enabled ancestor [Skeleton],
/// so [child] renders normally in regular content. Annotations can be nested:
/// [SkeletonDescendantBehavior.deferToChildren] allows deeper annotations to
/// apply, while [SkeletonDescendantBehavior.paintAsBone] and
/// [SkeletonDescendantBehavior.hide] finish the annotated branch.
///
/// See the [Skeleton guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/skeleton.md)
/// for behavior examples and nesting guidance.
class SkeletonDescendant extends StatelessWidget {
  /// Creates a skeleton annotation around [child].
  const new({
    required this.behavior,
    required this.child,
    super.key,
  });

  /// How the annotated subtree appears inside an enabled [Skeleton].
  final SkeletonDescendantBehavior behavior;

  /// The content shown when the enclosing skeleton is disabled.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final builder = switch (behavior) {
      _SkeletonPaintAsBoneBehavior(:final builder) => builder,
      _ => null,
    };
    if (builder == null) {
      return _SkeletonDescendantRenderObjectWidget(behavior: behavior, child: child);
    }

    final scope = _SkeletonScope.maybeOf(context);
    final enabled = scope?.enabled ?? false;
    return _SkeletonDescendantRenderObjectWidget(
      behavior: behavior,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Visibility(
            visible: !enabled,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: child,
          ),
          if (enabled)
            Positioned.fill(
              child: Builder(builder: builder),
            ),
        ],
      ),
    );
  }
}
