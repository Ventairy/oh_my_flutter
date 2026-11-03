part of 'route_settled.dart';

/// Runs actions in response to the enclosing route's navigation lifecycle,
/// without changing [child].
///
/// The settled callback runs after the route enters, after a covering route
/// leaves, or after a cancelled navigation gesture. Without an enclosing route,
/// the child is treated as settled. Callbacks do not run when this widget is
/// disposed. See the [RouteListener guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/route_listener.md).
class RouteListener extends StatefulWidget {
  /// Creates a listener for the enclosing route's navigation lifecycle.
  const new({required this.child, this.onSettled, this.onUnsettled, this.onProgressChanged, super.key})
    : assert(
        onSettled != null || onUnsettled != null || onProgressChanged != null,
        'Provide at least one route callback.',
      );

  /// The widget returned unchanged while the route is observed.
  final Widget child;

  /// Called when the route becomes current and its navigation motion finishes.
  final VoidCallback? onSettled;

  /// Called when the route starts leaving, becomes covered, or enters a gesture.
  final VoidCallback? onUnsettled;

  /// Called with the route's primary animation progress after each changed frame.
  ///
  /// Use a threshold such as `progress >= 0.6` to start an action during entry.
  /// Values increase from zero to one during entry and decrease during exit or
  /// an interactive back gesture. This is animation timeline progress, which
  /// may differ from the route's eased visual position. Covering routes do not
  /// contribute their animation progress.
  ///
  /// Reports the initial value after mounting, then only changed values, with
  /// multiple changes in one frame coalesced to the latest value. Without a
  /// route or primary animation, reports one. Replacing this callback does not
  /// replay the value; enabling it after it was null reports the current value.
  /// No callbacks run after disposal.
  final ValueChanged<double>? onProgressChanged;

  @override
  State<RouteListener> createState() => _RouteListenerState();
}

class _RouteListenerState extends State<RouteListener> with _RouteSettlementState<RouteListener> {
  final List<bool> _pendingSettlements = [];
  bool _deliveryScheduled = false;
  Animation<double>? _progressAnimation;
  bool _observingProgress = false;
  bool _progressDeliveryScheduled = false;
  double? _pendingProgress;
  double? _lastDeliveredProgress;

  void _observeProgress() {
    final enabled = widget.onProgressChanged != null;
    final animation = enabled ? ModalRoute.of(context)?.animation : null;
    if (enabled == _observingProgress && identical(animation, _progressAnimation)) return;

    _progressAnimation?.removeListener(_handleProgressChanged);
    _progressAnimation = animation;
    _observingProgress = enabled;
    _pendingProgress = null;
    _lastDeliveredProgress = null;
    if (!enabled) return;

    _progressAnimation?.addListener(_handleProgressChanged);
    _handleProgressChanged();
  }

  void _handleProgressChanged() {
    _pendingProgress = _progressAnimation?.value ?? 1;
    if (_progressDeliveryScheduled) return;
    _progressDeliveryScheduled = true;
    unawaited(
      WidgetsBinding.instance.endOfFrame.then((_) {
        _progressDeliveryScheduled = false;
        if (!mounted || !_observingProgress) return;
        final progress = _pendingProgress;
        _pendingProgress = null;
        if (progress == null || progress == _lastDeliveredProgress) return;
        _lastDeliveredProgress = progress;
        widget.onProgressChanged?.call(progress);
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observeProgress();
  }

  @override
  void didUpdateWidget(covariant RouteListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    _observeProgress();
  }

  @override
  void dispose() {
    _progressAnimation?.removeListener(_handleProgressChanged);
    super.dispose();
  }

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
