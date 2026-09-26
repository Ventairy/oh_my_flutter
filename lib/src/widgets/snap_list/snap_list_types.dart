part of 'snap_list.dart';

/// Applies a custom scroll-driven effect to an arriving or departing item.
///
/// Pass [animation] to a [FadeTransition], [ScaleTransition], or another
/// transition wrapping [child]. Its value is between zero and one: arrival
/// uses zero before entry and one at rest;
/// departure uses zero at rest and one after exit. Cancellation rewinds these
/// values. Effects supplement the list's normal scrolling.
///
/// [SnapListTransitionDetails.isReverse] means travel toward a lower item index,
/// including in horizontal right-to-left lists. It stays unchanged while that
/// swipe is being cancelled.
/// To disable an effect in that direction, use its normal appearance there.
/// Keep the returned widget structure consistent across progress and direction
/// changes to preserve the state of [child], and reuse [child] instead of
/// building item content again. Each builder should produce normal appearance
/// at its resting progress value.
///
/// The animation stays the same for the lifetime of the mounted item and is
/// owned by the list; do not dispose it. Builders are not called for every value
/// change. For a custom effect that reads `animation.value`, use [AnimatedBuilder]
/// with the supplied [child]. Animation status describes increasing or decreasing
/// progress, independently of [SnapListTransitionDetails.isReverse], and uses
/// dismissed/completed at zero and one respectively. Inactive effects return to
/// their resting values.
/// While trailing content is shown, the last item keeps its completed outgoing
/// effect until the user returns or that departure finishes after an append.
/// Use [SnapListTransitionDetails.involvesTrailing] to opt out of effects during
/// the reveal, or [SnapListTransitionDetails.isTrailing] to opt out only for the
/// trailer. Keep the same widget structure and supply a resting animation value
/// when opting out so [child] retains its state.
///
/// Trailing content uses these same effects over its measured reveal distance.
/// Reduced motion supplies resting values. The incoming effect wraps the
/// outgoing effect when both are supplied; only the effect for the item's
/// current role progresses.
///
/// See the [SnapList guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/snap_list.md).
typedef SnapListTransitionBuilder = Widget Function(
  BuildContext context,
  Animation<double> animation,
  SnapListTransitionDetails details,
  Widget child,
);
