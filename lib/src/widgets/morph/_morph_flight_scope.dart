part of 'morph.dart';

class _MorphFlightScope extends InheritedWidget {
  const _MorphFlightScope({required super.child});

  static bool contains(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_MorphFlightScope>() != null;
  }

  @override
  bool updateShouldNotify(_MorphFlightScope oldWidget) => false;
}
