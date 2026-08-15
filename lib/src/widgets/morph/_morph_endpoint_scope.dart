part of 'morph.dart';

class _MorphEndpointScope extends InheritedWidget {
  const _MorphEndpointScope({
    required this.endpoint,
    required this.duration,
    required this.curve,
    required super.child,
  });

  final _MorphEndpointHandle endpoint;
  final Duration duration;
  final Curve curve;

  static _MorphEndpointHandle? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_MorphEndpointScope>()?.endpoint;
  }

  @override
  bool updateShouldNotify(_MorphEndpointScope oldWidget) {
    return !identical(endpoint, oldWidget.endpoint) || duration != oldWidget.duration || curve != oldWidget.curve;
  }
}
