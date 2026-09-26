part of 'route_settled.dart';

/// Runs callbacks when the enclosing route becomes ready for interaction or
/// starts moving again, without changing [child].
///
/// The settled callback runs after the route enters, after a covering route
/// leaves, or after a cancelled navigation gesture. Without an enclosing route,
/// the child is treated as settled. Callbacks do not run when this widget is
/// disposed. See the [RouteListener guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/route_listener.md).
class RouteListener extends StatefulWidget {
  /// Creates a listener for changes to the enclosing route's settled state.
  const new({required this.child, this.onSettled, this.onUnsettled, super.key})
    : assert(onSettled != null || onUnsettled != null, 'Provide at least one route callback.');

  /// The widget returned unchanged while the route is observed.
  final Widget child;

  /// Called when the route becomes current and its navigation motion finishes.
  final VoidCallback? onSettled;

  /// Called when the route starts leaving, becomes covered, or enters a gesture.
  final VoidCallback? onUnsettled;

  @override
  State<RouteListener> createState() => _RouteListenerState();
}

class _RouteListenerState extends State<RouteListener> with _RouteSettlementState<RouteListener> {
  final List<bool> _pendingSettlements = [];
  bool _deliveryScheduled = false;

  @override
  void onRouteSettlementChanged({required bool settled}) {
    _pendingSettlements.add(settled);
    if (_deliveryScheduled) return;
    _deliveryScheduled = true;
    unawaited(
      WidgetsBinding.instance.endOfFrame.then((_) {
        _deliveryScheduled = false;
        if (!mounted) return;
        final events = List<bool>.of(_pendingSettlements);
        _pendingSettlements.clear();
        for (final event in events) {
          if (!mounted) return;
          if (event) {
            widget.onSettled?.call();
          } else {
            widget.onUnsettled?.call();
          }
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
