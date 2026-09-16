part of 'morph.dart';

class _MorphScope extends InheritedWidget {
  const _MorphScope({required this.enabled, required super.child});

  final bool enabled;

  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MorphScope>()?.enabled ?? true;

  @override
  bool updateShouldNotify(_MorphScope oldWidget) => enabled != oldWidget.enabled;
}
