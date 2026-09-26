part of 'snap_list.dart';

/// Identifies the child and navigation involved in a SnapList effect.
///
/// Use [isTrailing] to customize only the trailing child, or [involvesTrailing]
/// to customize both sides of its reveal. These values are supplied to
/// [SnapListTransitionBuilder] and do not change the list's scroll geometry.
@immutable
class SnapListTransitionDetails {
  /// Describes the child receiving an incoming or outgoing effect.
  const new({required this.isReverse, required this.isTrailing, required this.involvesTrailing});

  /// Whether navigation is toward a lower index, including horizontal RTL lists.
  ///
  /// Rewinding a cancelled swipe keeps its original direction.
  final bool isReverse;

  /// Whether the supplied child was built by [SnapList.trailingBuilder].
  ///
  /// This remains false for the last real item, even during a trailing reveal.
  final bool isTrailing;

  /// Whether this child's effect belongs to revealing or hiding trailing content.
  ///
  /// This is true for the trailer and for the last item's effects during that
  /// reveal. It stays true for a departure continuing after items are appended,
  /// until that departure finishes or is cancelled.
  final bool involvesTrailing;
}
