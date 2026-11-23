part of 'snap_list.dart';

final class _SnapListEveryTransientItem extends SnapListTransientItem {
  const new(this.interval, {required NullableIndexedWidgetBuilder builder})
    : assert(interval > 0, 'interval must be positive.'),
      super._(builder);

  final int interval;

  @override
  bool _matches(int mainIndex) => (mainIndex + 1) % interval == 0;
}
