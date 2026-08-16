part of 'morph.dart';

class _MorphFlightScope extends InheritedWidget {
  const _MorphFlightScope({
    required this.descendantResolver,
    required super.child,
  });

  final _MorphDescendantFlightResolver? descendantResolver;

  static bool contains(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_MorphFlightScope>() != null;
  }

  static _MorphDescendantFlightResolver? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_MorphFlightScope>()?.descendantResolver;
  }

  @override
  bool updateShouldNotify(_MorphFlightScope oldWidget) {
    return !identical(descendantResolver, oldWidget.descendantResolver);
  }
}
