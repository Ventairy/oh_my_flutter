part of 'skeleton.dart';

class _SkeletonScope extends InheritedWidget {
  const new({
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static _SkeletonScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_SkeletonScope>();

  @override
  bool updateShouldNotify(_SkeletonScope oldWidget) => enabled != oldWidget.enabled;
}
