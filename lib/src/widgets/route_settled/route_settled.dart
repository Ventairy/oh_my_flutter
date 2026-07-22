import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:oh_my_flutter/src/widgets/controlled_visibility/controlled_visibility.dart';

/// A visibility wrapper that shows [child] after its route settles.
///
/// The child remains hidden while the enclosing route is entering, leaving,
/// or participating in a navigator user gesture. This is useful for route
/// chrome that should not overlap navigation motion, such as back buttons,
/// dismiss handles, or secondary actions.
///
/// [RouteSettled] provides no built-in visual treatment. Supply
/// [showTransition], [hideTransition], or both to animate a direction. A
/// missing transition changes visibility immediately in that direction.
///
/// The visibility rule is:
///
/// ```text
/// visible = route animation completed && no user gesture in progress
/// ```
///
/// When no enclosing [ModalRoute] exists, the child is treated as settled and
/// shown.
///
/// ```dart
/// RouteSettled(
///   showTransition: (child, animation) => FadeTransition(
///     opacity: animation,
///     child: child,
///   ),
///   child: const Text('Ready'),
/// )
/// ```
class RouteSettled extends StatefulWidget {
  /// Creates a route-aware visibility wrapper around [child].
  const RouteSettled({
    required this.child,
    this.showTransition,
    this.hideTransition,
    this.showDuration = const Duration(milliseconds: 300),
    this.hideDuration = Duration.zero,
    super.key,
  });

  /// Widget shown only while the enclosing route is settled.
  final Widget child;

  /// Builder for the optional transition when the route settles.
  final Widget Function(Widget child, Animation<double> animation)? showTransition;

  /// Builder for the optional transition when the route starts moving.
  final Widget Function(Widget child, Animation<double> animation)? hideTransition;

  /// Duration of [showTransition].
  ///
  /// This value is ignored when [showTransition] is `null` or when the
  /// platform requests reduced motion.
  final Duration showDuration;

  /// Duration of [hideTransition].
  ///
  /// This value is ignored when [hideTransition] is `null` or when the
  /// platform requests reduced motion. The default is [Duration.zero].
  final Duration hideDuration;

  @override
  State<RouteSettled> createState() => _RouteSettledState();
}

class _RouteSettledState extends State<RouteSettled> {
  final ControlledVisibilityController _controller = ControlledVisibilityController();
  Animation<double>? _routeAnimation;
  ValueListenable<bool>? _gestureNotifier;
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeAnimation != null) return;

    final route = ModalRoute.of(context);
    if (route == null) {
      _controller.show();
      _visible = true;
      return;
    }

    _routeAnimation = route.animation;
    _routeAnimation?.addStatusListener(_handleStatusChanged);

    final navigator = Navigator.maybeOf(context);
    if (navigator != null) {
      _gestureNotifier = navigator.userGestureInProgressNotifier;
      _gestureNotifier?.addListener(_handleGestureChanged);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateVisibility();
    });
  }

  void _handleStatusChanged(AnimationStatus status) => _updateVisibility();

  void _handleGestureChanged() => _updateVisibility();

  void _updateVisibility() {
    final routeAnimation = _routeAnimation;
    if (routeAnimation == null) return;

    final settled = routeAnimation.status == AnimationStatus.completed;
    final gestureActive = _gestureNotifier?.value ?? false;
    final shouldShow = settled && !gestureActive;
    if (shouldShow == _visible) return;

    _visible = shouldShow;
    shouldShow ? _controller.show() : _controller.hide();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleStatusChanged);
    _gestureNotifier?.removeListener(_handleGestureChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ControlledVisibility(
      controller: _controller,
      showTransition: widget.showTransition,
      hideTransition: widget.hideTransition,
      showDuration: widget.showDuration,
      hideDuration: widget.hideDuration,
      child: widget.child,
    );
  }
}
