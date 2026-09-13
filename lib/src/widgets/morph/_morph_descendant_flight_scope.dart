part of 'morph.dart';

class _MorphDescendantFlightScope extends InheritedWidget {
  const _MorphDescendantFlightScope({
    required this.flightScope,
    required this.resolver,
    required super.child,
  });

  final _MorphFlightScope? flightScope;
  final _MorphDescendantFlightResolver? resolver;

  static _MorphDescendantFlightScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_MorphDescendantFlightScope>();
  }

  @override
  bool updateShouldNotify(_MorphDescendantFlightScope oldWidget) {
    return !identical(flightScope, oldWidget.flightScope) || !identical(resolver, oldWidget.resolver);
  }
}
