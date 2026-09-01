part of 'interactive_swipe_dismiss.dart';

class _InteractiveSwipeDismissScope extends InheritedWidget {
  const _InteractiveSwipeDismissScope({
    required this.coordinator,
    required super.child,
  });

  final _InteractiveSwipeDismissCoordinator coordinator;

  static _InteractiveSwipeDismissScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_InteractiveSwipeDismissScope>();
  }

  @override
  bool updateShouldNotify(_InteractiveSwipeDismissScope oldWidget) {
    return coordinator != oldWidget.coordinator;
  }
}
