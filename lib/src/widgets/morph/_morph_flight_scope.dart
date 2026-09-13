part of 'morph.dart';

class _MorphFlightScope extends InheritedNotifier<_MorphCoordinator> {
  const _MorphFlightScope({
    required this.coordinator,
    required this.registeredCaptures,
    required super.child,
  }) : super(notifier: coordinator);

  final _MorphCoordinator coordinator;
  final Set<_MorphDescendantCapture> registeredCaptures;

  static _MorphFlightScope? scopeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_MorphFlightScope>();
  }

  static bool contains(BuildContext context) {
    return scopeOf(context) != null;
  }

  bool hasFlight(Object tag) {
    return coordinator._flights.containsKey(tag);
  }

  @override
  bool updateShouldNotify(_MorphFlightScope oldWidget) {
    return super.updateShouldNotify(oldWidget) || !identical(registeredCaptures, oldWidget.registeredCaptures);
  }
}
