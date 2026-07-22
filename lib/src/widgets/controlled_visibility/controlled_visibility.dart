import 'dart:async';

import 'package:flutter/widgets.dart';

part 'controlled_visibility_controller.dart';

/// A controller-driven wrapper that shows or hides [child].
///
/// [ControlledVisibility] owns visibility state, lifecycle, timing, and
/// reduced-motion behavior without prescribing a visual animation. Supply
/// [showTransition], [hideTransition], or both when a direction should be
/// animated. Each transition receives an animation from `0` (hidden) to `1`
/// (shown).
///
/// When a direction's transition is omitted, its controller command changes
/// visibility immediately and the corresponding duration is ignored.
///
/// By default, hidden content remains mounted and keeps its layout space, but
/// cannot receive pointer input and is excluded from semantics. Set [unmount]
/// to `true` to dispose the child after hiding. Showing it again creates a new
/// element subtree before an optional transition begins.
///
/// ```dart
/// final controller = ControlledVisibilityController();
///
/// ControlledVisibility(
///   controller: controller,
///   showTransition: (child, animation) => FadeTransition(
///     opacity: CurveTween(curve: Curves.easeOutCubic).animate(animation),
///     child: child,
///   ),
///   hideTransition: (child, animation) => FadeTransition(
///     opacity: animation,
///     child: child,
///   ),
///   child: const Text('Details'),
/// )
/// ```
class ControlledVisibility extends StatefulWidget {
  /// Creates a controller-driven visibility wrapper around [child].
  const ControlledVisibility({
    required this.controller,
    required this.child,
    this.showTransition,
    this.hideTransition,
    this.showDuration = const Duration(milliseconds: 300),
    this.hideDuration = const Duration(milliseconds: 300),
    this.unmount = false,
    this.onShow,
    this.onHide,
    super.key,
  });

  /// Controller that shows or hides [child].
  final ControlledVisibilityController controller;

  /// Widget whose visibility is controlled.
  final Widget child;

  /// Builder for the optional visual transition while showing [child].
  ///
  /// The animation runs from `0` to `1`. When `null`, showing is immediate.
  final Widget Function(Widget child, Animation<double> animation)? showTransition;

  /// Builder for the optional visual transition while hiding [child].
  ///
  /// The animation runs from `1` to `0`. When `null`, hiding is immediate.
  final Widget Function(Widget child, Animation<double> animation)? hideTransition;

  /// Duration of the optional transition while showing [child].
  ///
  /// This value is ignored when [showTransition] is `null` or when the
  /// platform requests reduced motion.
  final Duration showDuration;

  /// Duration of the optional transition while hiding [child].
  ///
  /// This value is ignored when [hideTransition] is `null` or when the
  /// platform requests reduced motion.
  final Duration hideDuration;

  /// Whether [child] is removed from the widget tree after it is hidden.
  ///
  /// When `false`, the hidden child retains its state and layout space while
  /// input and semantics remain disabled. When `true`, hiding disposes the
  /// child and showing creates a fresh subtree.
  final bool unmount;

  /// Callback invoked immediately when a show operation is requested.
  ///
  /// The supplied future completes when the optional transition finishes, or
  /// immediately when no transition runs. A later visibility command also
  /// completes an interrupted operation's future.
  ///
  /// Await the future inside the callback to run work after the show operation
  /// settles:
  ///
  /// ```dart
  /// onShow: (transition) async {
  ///   await transition;
  ///   // Continue after the transition finishes or is interrupted.
  /// },
  /// ```
  final void Function(Future<void> transition)? onShow;

  /// Callback invoked immediately when a hide operation is requested.
  ///
  /// The supplied future completes when the optional transition finishes, or
  /// immediately when no transition runs. A later visibility command also
  /// completes an interrupted operation's future.
  ///
  /// Await the future inside the callback to run work after the hide operation
  /// settles:
  ///
  /// ```dart
  /// onHide: (transition) async {
  ///   await transition;
  ///   // Continue after the transition finishes or is interrupted.
  /// },
  /// ```
  final void Function(Future<void> transition)? onHide;

  @override
  State<ControlledVisibility> createState() => _ControlledVisibilityState();
}

class _ControlledVisibilityState extends State<ControlledVisibility> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  final GlobalKey _childKey = GlobalKey(debugLabel: 'controlled_visibility_child');
  late bool _hidden;
  late bool _unmounted;
  Widget Function(Widget child, Animation<double> animation)? _activeTransition;
  bool _dependenciesReady = false;
  bool? _pendingVisibility;
  Completer<void>? _showCompleter;
  Completer<void>? _hideCompleter;

  @override
  void initState() {
    super.initState();
    _hidden = true;
    _unmounted = widget.unmount;
    _animationController = AnimationController(
      duration: widget.showDuration,
      reverseDuration: widget.hideDuration,
      vsync: this,
    )..addStatusListener(_handleAnimationStatus);
    widget.controller._register(_handleVisibilityRequest);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesReady) return;

    _dependenciesReady = true;
    final pendingVisibility = _pendingVisibility;
    if (pendingVisibility == null) return;

    _pendingVisibility = null;
    _applyVisibility(pendingVisibility);
  }

  @override
  void didUpdateWidget(covariant ControlledVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._unregister();
      widget.controller._register(_handleVisibilityRequest);
    }

    if (oldWidget.showDuration != widget.showDuration) {
      _animationController.duration = widget.showDuration;
    }

    if (oldWidget.hideDuration != widget.hideDuration) {
      _animationController.reverseDuration = widget.hideDuration;
    }

    if (!oldWidget.unmount && widget.unmount && _hidden) {
      _unmounted = true;
    }

    if (oldWidget.unmount && !widget.unmount && _unmounted) {
      _unmounted = false;
    }
  }

  @override
  void dispose() {
    widget.controller._unregister();

    _animationController
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();

    _completeOperations();
    super.dispose();
  }

  void _handleVisibilityRequest({required bool visible}) {
    if (!mounted) return;

    _animationController.stop();
    _completeOperations();

    final completer = Completer<void>();

    if (visible) {
      _showCompleter = completer;
      widget.onShow?.call(completer.future);
    } else {
      _hideCompleter = completer;
      widget.onHide?.call(completer.future);
    }

    if (!_dependenciesReady) {
      _pendingVisibility = visible;
      return;
    }

    _applyVisibility(visible);
  }

  void _applyVisibility(bool visible) {
    final animationsDisabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final transition = visible ? widget.showTransition : widget.hideTransition;
    final animate = transition != null && !animationsDisabled;

    if (!animate) {
      _animationController.value = visible ? 1 : 0;
      _setEndpointState(visible: visible, transition: null);
      visible ? _completeShow() : _completeHide();
      return;
    }

    if (visible) {
      if (_animationController.value == 1 && !_hidden && !_unmounted) {
        _completeShow();
        return;
      }

      final needsTransitionRebuild = _activeTransition != transition;

      if (_unmounted || _hidden || needsTransitionRebuild) {
        setState(() {
          _unmounted = false;
          _hidden = false;
          _activeTransition = transition;
        });
      }

      unawaited(_animationController.forward());
      return;
    }

    if (_animationController.value == 0) {
      _setEndpointState(visible: false, transition: transition);
      _completeHide();
      return;
    }

    if (_activeTransition != transition) {
      setState(() => _activeTransition = transition);
    }
    unawaited(_animationController.reverse());
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _setEndpointState(visible: true, transition: widget.showTransition);
      _completeShow();
    } else if (status == AnimationStatus.dismissed) {
      _setEndpointState(visible: false, transition: widget.hideTransition);
      _completeHide();
    }
  }

  void _setEndpointState({
    required bool visible,
    required Widget Function(Widget child, Animation<double> animation)? transition,
  }) {
    final hidden = !visible;
    final unmounted = hidden && widget.unmount;
    if (_hidden == hidden && _unmounted == unmounted && _activeTransition == transition) {
      return;
    }

    setState(() {
      _hidden = hidden;
      _unmounted = unmounted;
      _activeTransition = transition;
    });
  }

  void _completeOperations() {
    _completeShow();
    _completeHide();
  }

  void _completeShow() {
    final completer = _showCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
    _showCompleter = null;
  }

  void _completeHide() {
    final completer = _hideCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
    _hideCompleter = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_unmounted) return const SizedBox.shrink();

    final wrappedChild = KeyedSubtree(key: _childKey, child: widget.child);
    final transition = _activeTransition;
    final child = transition == null ? wrappedChild : transition(wrappedChild, _animationController);

    if (widget.unmount) return child;

    return Visibility(
      visible: !_hidden,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: child,
    );
  }
}
