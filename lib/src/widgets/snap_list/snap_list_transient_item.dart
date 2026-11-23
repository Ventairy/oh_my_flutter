part of 'snap_list.dart';

/// Offers additional swipeable content without changing main-item coordinates.
@immutable
sealed class SnapListTransientItem {
  const new _(this.builder);

  /// Offers a page after every [interval] main items, including a final complete group.
  const factory every(int interval, {required NullableIndexedWidgetBuilder builder}) = _SnapListEveryTransientItem;

  /// Builds content after the given zero-based main index. Return null to skip it.
  ///
  /// The builder can run repeatedly. Read prepared content here and start
  /// asynchronous work outside the builder.
  final NullableIndexedWidgetBuilder builder;

  bool _matches(int mainIndex);
}
