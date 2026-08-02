part of 'sequence.dart';

/// Builds a visual transition around a child of a [Sequence].
///
/// The animation value is `0` while the child is hidden and `1` while it is
/// visible.
typedef SequenceTransitionBuilder = Widget Function(Widget child, Animation<double> animation);
