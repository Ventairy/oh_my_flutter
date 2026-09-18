import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

part '_interactive_swipe_dismiss_coordinator.dart';
part '_interactive_swipe_dismiss_handle_gesture_recognizer.dart';
part '_interactive_swipe_dismiss_scope.dart';
part '_interactive_swipe_dismiss_scroll_edge.dart';
part '_interactive_swipe_dismiss_scroll_source.dart';
part '_interactive_swipe_dismiss_translation.dart';
part '_interactive_swipe_dismiss_translation_controller.dart';
part '_interactive_swipe_dismiss_translation_layer.dart';
part '_render_interactive_swipe_dismiss_translation.dart';
part 'interactive_swipe_dismiss_direction.dart';
part 'interactive_swipe_dismiss_drag_config.dart';
part 'interactive_swipe_dismiss_handle.dart';

/// Lets a user drag any child away to request its dismissal.
///
/// By default, a downward drag moves [child] directly with the pointer.
/// Releasing after halfway, or swiping quickly in [direction], calls
/// [onDismiss]. The callback owns removal, so this widget works for routes,
/// overlays, list items, and other consumer-managed content.
///
/// Descendant scrollables keep their normal interaction until they reach the
/// edge matching [direction]. Once dismissal begins, the matching scroll chain
/// stays fixed until the gesture ends. An [InteractiveSwipeDismissHandle] can
/// always begin dismissal, independently of descendant scroll position.
///
/// See the [InteractiveSwipeDismiss guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/interactive_swipe_dismiss.md)
/// for usage examples.
class InteractiveSwipeDismiss extends StatefulWidget {
  /// Creates a live drag-to-dismiss interaction around [child].
  const InteractiveSwipeDismiss({
    required this.child,
    required this.onDismiss,
    this.canStartDrag,
    this.onOverdrag,
    this.onPositionChanged,
    this.direction = InteractiveSwipeDismissDirection.down,
    this.dragConfig = const InteractiveSwipeDismissDragConfig(),
    super.key,
  });

  /// The content translated during the drag.
  final Widget child;

  /// Decides whether a new touch may start dragging the child.
  ///
  /// Omit this callback to allow dragging. Return `false` to leave the touch
  /// available to descendant interactions without translating the child or
  /// calling [onOverdrag], [onPositionChanged], or [onDismiss]. Handles follow
  /// the same decision.
  ///
  /// Called once at pointer down for each eligible touch, including touches
  /// that never become drags. Keep this check quick and free of side effects.
  /// The decision lasts until release or cancellation; changes apply to the
  /// next touch without requiring a rebuild. Use [onDismiss] to recheck before
  /// accepting removal. A thrown exception is reported and blocks that touch.
  final bool Function()? canStartDrag;

  /// Requests removal after a drag or fling commits.
  ///
  /// Return `true` after accepting the request. The child remains at its final
  /// translated position until its owner removes it. Return `false` to restore
  /// the child. The callback may complete synchronously or asynchronously and
  /// is called at most once per gesture.
  final FutureOr<bool> Function() onDismiss;

  /// Reports how far the child has moved from its resting position.
  ///
  /// Use this to keep other content in sync with dragging and returning home.
  /// The offset uses logical pixels after sensitivity and direction constraints,
  /// with negative x for left and negative y for up. Free drag reports both axes.
  ///
  /// Called synchronously for every distinct translation, including each return
  /// animation update and [Offset.zero] when the child returns home. Unchanged
  /// positions, initial mounting, and disposal do not notify. Reduced motion
  /// does not notify when the child stays stationary. Accepted dismissal keeps
  /// the final position and does not report an artificial reset.
  ///
  /// `directionalFraction` measures translation toward [direction] divided by
  /// the child's height for up/down or width for left/right. A value of `1.0`
  /// means one full child size; values can exceed `1.0`. Sideways movement does
  /// not contribute, and opposite movement reports zero. Both values reflect
  /// sensitivity; this fraction is independent of the raw finger travel used
  /// by [InteractiveSwipeDismissDragConfig.dismissFraction].
  ///
  ///
  /// The callback is captured at gesture start and retained through the return;
  /// changes apply to the next gesture.
  final void Function(Offset offset, double directionalFraction)? onPositionChanged;

  /// Reports total finger movement that cannot translate the child.
  ///
  /// Offsets use logical pixels before [InteractiveSwipeDismissDragConfig.sensitivity], with negative x for left
  /// and negative y for up. Both components may be nonzero. The callback runs
  /// when the restricted offset changes and reports [Offset.zero] when the
  /// finger returns to an allowed offset, or the gesture ends or cancels.
  /// If the initial direction rules out dismissal, the entire drag offset is
  /// reported, including subsequent movement toward the dismissal direction.
  /// The callback is captured at gesture start; changes apply next gesture.
  ///
  /// This notification does not move the child. [InteractiveSwipeDismissDragConfig.freeDrag] bypasses it because
  /// movement is unrestricted. Reduced motion still reports gesture offsets;
  /// consumers own any visual response and its accessibility behavior.
  final void Function(Offset offset)? onOverdrag;

  /// The direction that can dismiss [child].
  ///
  /// This controls gesture recognition, scroll-edge arbitration, drag
  /// commitment, and fling commitment. A gesture must initially favor this
  /// direction after the activation distance. Starting opposite
  /// cannot become a dismissal until the finger lifts and starts a new gesture.
  final InteractiveSwipeDismissDirection direction;

  /// Configuration that changes how pointer travel translates [child] and
  /// when the drag commits.
  final InteractiveSwipeDismissDragConfig dragConfig;

  @override
  State<InteractiveSwipeDismiss> createState() => _InteractiveSwipeDismissState();
}

class _InteractiveSwipeDismissState extends State<InteractiveSwipeDismiss> with SingleTickerProviderStateMixin {
  static const _activationDistance = 10.0;
  static const _minimumFlingVelocity = 700.0;
  static const _flingCooldown = Duration(milliseconds: 120);
  static const _scrollEdgeTolerance = 0.5;
  static const _scrollAwayThreshold = 5.0;
  static const _fastScrollDeltaThreshold = 15.0;
  static final Map<({int pointer, int viewId}), _InteractiveSwipeDismissState> _pointerOwners =
      <({int pointer, int viewId}), _InteractiveSwipeDismissState>{};

  late final _InteractiveSwipeDismissCoordinator _coordinator;
  final _InteractiveSwipeDismissTranslationController _translationController =
      _InteractiveSwipeDismissTranslationController();
  AnimationController? _restoreController;

  final Set<({int pointer, int viewId})> _deniedPointers = {};

  int? _activePointer;
  ({int pointer, int viewId})? _ownedPointerKey;
  int _gestureGeneration = 0;
  bool _pointerOwnedByHandle = false;
  bool _isInteractionActive = false;
  bool _isDirectionRejected = false;
  bool? _initialDirectionAllowsDismissal;
  bool _isReducedMotion = false;
  bool _isAwaitingDismissal = false;
  bool _isCommitted = false;
  bool _isStartingScrollHold = false;
  bool _isReleasingScrollHold = false;
  bool _isScrollFreezeScheduled = false;
  bool _isApplyingScrollFreeze = false;
  bool _surfaceWasBlockedByScroll = false;
  bool _resetScrollMovementAfterGesture = false;
  double? _childExtent;
  Offset _overdragOffset = Offset.zero;
  Duration? _pointerDownTimeStamp;
  Duration? _previousPointerTimeStamp;
  Offset? _pointerDownPosition;
  Offset? _previousPointerPosition;
  PointerDeviceKind? _pointerDeviceKind;
  InteractiveSwipeDismissDirection? _gestureDirection;
  InteractiveSwipeDismissDragConfig? _gestureDragConfig;
  void Function(Offset)? _gestureOnOverdrag;
  void Function(Offset, double)? _gestureOnPositionChanged;
  double _pointerDx = 0;
  double _pointerDy = 0;
  double _interactionStartDx = 0;
  double _interactionStartDy = 0;
  double _restoreStartDx = 0;
  double _restoreStartDy = 0;
  final Expando<_InteractiveSwipeDismissScrollSource> _scrollSourceByScrollable =
      Expando<_InteractiveSwipeDismissScrollSource>();
  final Expando<_InteractiveSwipeDismissScrollSource> _scrollSourceByNotificationContext =
      Expando<_InteractiveSwipeDismissScrollSource>();
  final List<WeakReference<ScrollableState>> _registeredScrollables = <WeakReference<ScrollableState>>[];
  final List<_InteractiveSwipeDismissScrollSource> _activeScrollSources = <_InteractiveSwipeDismissScrollSource>[];
  final List<_InteractiveSwipeDismissScrollSource> _frozenScrollSources = <_InteractiveSwipeDismissScrollSource>[];
  VelocityTracker? _velocityTracker;
  int _scrollRegistrationsSinceCompaction = 0;
  int _scrollFreezeRevision = 0;

  static Axis _axisFor(InteractiveSwipeDismissDirection direction) {
    return switch (direction) {
      InteractiveSwipeDismissDirection.down || InteractiveSwipeDismissDirection.up => Axis.vertical,
      InteractiveSwipeDismissDirection.left || InteractiveSwipeDismissDirection.right => Axis.horizontal,
    };
  }

  InteractiveSwipeDismissDirection get _effectiveDirection {
    return _gestureDirection ?? widget.direction;
  }

  InteractiveSwipeDismissDragConfig get _effectiveDragConfig {
    return _gestureDragConfig ?? widget.dragConfig;
  }

  void Function(Offset)? get _effectiveOnOverdrag =>
      _gestureDragConfig != null ? _gestureOnOverdrag : widget.onOverdrag;

  bool get _hasOverdrag => !_effectiveDragConfig.freeDrag && _effectiveOnOverdrag != null;

  Axis get _axis => _axisFor(_effectiveDirection);

  AxisDirection get _dismissalAxisDirection => switch (_effectiveDirection) {
    InteractiveSwipeDismissDirection.down => AxisDirection.down,
    InteractiveSwipeDismissDirection.up => AxisDirection.up,
    InteractiveSwipeDismissDirection.left => AxisDirection.left,
    InteractiveSwipeDismissDirection.right => AxisDirection.right,
  };

  double get _interactionDx => _pointerDx - _interactionStartDx;

  double get _interactionDy => _pointerDy - _interactionStartDy;

  bool _usesMinimumScrollEdge(ScrollMetrics metrics) {
    return metrics.axisDirection == _dismissalAxisDirection;
  }

  double _signedPrimary(double dx, double dy) {
    return switch (_effectiveDirection) {
      InteractiveSwipeDismissDirection.down => dy,
      InteractiveSwipeDismissDirection.up => -dy,
      InteractiveSwipeDismissDirection.left => -dx,
      InteractiveSwipeDismissDirection.right => dx,
    };
  }

  double _crossAxis(double dx, double dy) {
    return switch (_axis) {
      Axis.horizontal => dy,
      Axis.vertical => dx,
    };
  }

  bool get _isAtDismissalEdge {
    for (final source in _activeScrollSources) {
      if (!_isAtDismissalEdgeFor(source.position)) return false;
    }
    return true;
  }

  bool _isAtDismissalEdgeFor(ScrollMetrics metrics) {
    if (metrics.maxScrollExtent <= metrics.minScrollExtent + _scrollEdgeTolerance) {
      return true;
    }
    if (_usesMinimumScrollEdge(metrics)) {
      return metrics.pixels <= metrics.minScrollExtent + _scrollEdgeTolerance;
    }
    return metrics.pixels >= metrics.maxScrollExtent - _scrollEdgeTolerance;
  }

  bool _canStartOverdragFromSurface(Offset delta) {
    for (final source in _activeScrollSources) {
      final position = source.position;
      final component = position.axis == Axis.horizontal ? delta.dx : delta.dy;
      if (component == 0) continue;
      final positiveAxis =
          position.axisDirection == AxisDirection.down || position.axisDirection == AxisDirection.right;
      final minimum = (component > 0) == positiveAxis;
      final distance = minimum
          ? position.pixels - position.minScrollExtent
          : position.maxScrollExtent - position.pixels;
      if (distance > _scrollEdgeTolerance) return false;
      final edge = minimum ? source.minimumEdge : source.maximumEdge;
      if (edge.isCoolingDown) return false;
    }
    return true;
  }

  bool get _canStartFromSurface {
    if (!_isAtDismissalEdge) return false;
    final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    for (final source in _activeScrollSources) {
      final reachedEdgeAt = source.flingReachedEdgeAt;
      if (reachedEdgeAt != null && now - reachedEdgeAt < _flingCooldown) {
        return false;
      }
    }
    return true;
  }

  bool _hasDirectionalIntent() {
    if (_hasOverdrag) return Offset(_pointerDx, _pointerDy).distance >= _activationDistance;
    final primary = _signedPrimary(_pointerDx, _pointerDy);
    final cross = _crossAxis(_pointerDx, _pointerDy).abs();
    return primary >= _activationDistance && primary > cross;
  }

  bool _shouldRejectDirection() {
    if (_hasOverdrag) return false;
    final primary = _signedPrimary(_pointerDx, _pointerDy);
    final cross = _crossAxis(_pointerDx, _pointerDy).abs();
    return primary <= -_activationDistance || (cross >= _activationDistance && cross >= primary.abs());
  }

  bool _moveFavorsDismissal(PointerMoveEvent event) {
    final primary = _signedPrimary(event.delta.dx, event.delta.dy);
    final cross = _crossAxis(event.delta.dx, event.delta.dy).abs();
    return primary > 0 && primary > cross;
  }

  Offset _dismissalOffset(Offset offset) {
    final primary = _signedPrimary(offset.dx, offset.dy).clamp(0.0, double.infinity);
    return switch (_effectiveDirection) {
      InteractiveSwipeDismissDirection.down => Offset(0, primary),
      InteractiveSwipeDismissDirection.up => Offset(0, -primary),
      InteractiveSwipeDismissDirection.left => Offset(-primary, 0),
      InteractiveSwipeDismissDirection.right => Offset(primary, 0),
    };
  }

  void _reportOverdrag(Offset offset) {
    if (!_hasOverdrag || offset == _overdragOffset) return;
    _overdragOffset = offset;
    _effectiveOnOverdrag!(offset);
  }

  void _setTranslation(double dx, double dy) {
    if (_translationController.dx == dx && _translationController.dy == dy) return;
    _translationController.setTranslation(dx, dy);
    final extent = _childExtent;
    _gestureOnPositionChanged?.call(
      Offset(dx, dy),
      extent == null ? 0.0 : _signedPrimary(dx, dy).clamp(0.0, double.infinity) / extent,
    );
  }

  void _updateVisualTranslation() {
    if (_initialDirectionAllowsDismissal != true) return;
    final config = _effectiveDragConfig;
    final raw = Offset(_interactionDx, _interactionDy);
    final offset = (config.freeDrag ? raw : _dismissalOffset(raw)) * config.sensitivity;
    _setTranslation(offset.dx, offset.dy);
  }

  void _startInteraction(
    PointerMoveEvent event, {
    required bool fromHandle,
    required Duration? previousTimeStamp,
    required Offset? previousPosition,
  }) {
    _restoreController?.stop();
    _isInteractionActive = true;
    if (!fromHandle && _surfaceWasBlockedByScroll) {
      _interactionStartDx = _pointerDx - event.delta.dx;
      _interactionStartDy = _pointerDy - event.delta.dy;
    } else {
      _interactionStartDx = 0;
      _interactionStartDy = 0;
    }
    _freezeActiveScrollSources();
    final startTimeStamp = !fromHandle && _surfaceWasBlockedByScroll ? previousTimeStamp : _pointerDownTimeStamp;
    final startPosition = !fromHandle && _surfaceWasBlockedByScroll ? previousPosition : _pointerDownPosition;
    final deviceKind = _pointerDeviceKind;
    if (startTimeStamp != null && startPosition != null && deviceKind != null) {
      _velocityTracker = VelocityTracker.withKind(deviceKind)
        ..addPosition(startTimeStamp, startPosition)
        ..addPosition(event.timeStamp, event.position);
    }
  }

  bool _hasCommitVelocity(Velocity velocity) {
    final pixelsPerSecond = velocity.pixelsPerSecond;
    final speed = _signedPrimary(
      pixelsPerSecond.dx,
      pixelsPerSecond.dy,
    );
    final crossSpeed = _crossAxis(
      pixelsPerSecond.dx,
      pixelsPerSecond.dy,
    ).abs();
    return speed >= _minimumFlingVelocity && speed > crossSpeed;
  }

  void _finishInteraction() {
    if (!_isInteractionActive) {
      _resetGestureState();
      return;
    }
    if (_initialDirectionAllowsDismissal != true) {
      _cancelInteraction();
      return;
    }
    final extent = _childExtent;
    final distance = _signedPrimary(_interactionDx, _interactionDy);
    if (_hasOverdrag && distance <= 0) {
      _cancelInteraction();
      return;
    }
    if (extent != null && distance >= extent * _effectiveDragConfig.dismissFraction) {
      _requestDismissal();
      return;
    }
    final velocity = _velocityTracker?.getVelocity() ?? Velocity.zero;
    if (_hasCommitVelocity(velocity)) {
      _requestDismissal();
      return;
    }
    _cancelInteraction();
  }

  void _requestDismissal() {
    if (_isAwaitingDismissal) return;
    _reportOverdrag(Offset.zero);
    _isAwaitingDismissal = true;
    _isInteractionActive = false;
    _releaseActiveScrollHolds();
    unawaited(_resolveDismissal());
  }

  Future<void> _resolveDismissal() async {
    try {
      final accepted = await widget.onDismiss();
      if (!mounted) return;
      if (!accepted) {
        _isAwaitingDismissal = false;
        _cancelInteraction();
        return;
      }
      _isCommitted = true;
      _resetGestureState(keepVisualState: true);
    } on Object catch (error, stackTrace) {
      if (mounted) {
        _isAwaitingDismissal = false;
        _cancelInteraction();
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'oh_my_flutter',
          context: ErrorDescription(
            'while requesting an InteractiveSwipeDismiss dismissal',
          ),
        ),
      );
    }
  }

  void _cancelInteraction() {
    _reportOverdrag(Offset.zero);
    _isInteractionActive = false;
    _releaseActiveScrollHolds();
    if (_isReducedMotion || _effectiveDragConfig.returnDuration == Duration.zero) {
      _resetGestureState();
      return;
    }
    _restoreStartDx = _translationController.dx;
    _restoreStartDy = _translationController.dy;
    if (_restoreStartDx == 0 && _restoreStartDy == 0) {
      _resetGestureState();
      return;
    }
    (_restoreController ??= _createRestoreController())
      ..duration = _effectiveDragConfig.returnDuration
      ..value = 0
      ..forward();
  }

  void _handleRestoreTick() {
    final remaining = 1 - _effectiveDragConfig.returnCurve.transform(_restoreController!.value);
    _setTranslation(
      _restoreStartDx * remaining,
      _restoreStartDy * remaining,
    );
  }

  AnimationController _createRestoreController() {
    return AnimationController(vsync: this)
      ..addListener(_handleRestoreTick)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        _resetGestureState();
      });
  }

  void _resetGestureState({bool keepVisualState = false}) {
    _reportOverdrag(Offset.zero);
    _gestureGeneration += 1;
    _scrollFreezeRevision += 1;
    _releasePointerOwnership();
    _activePointer = null;
    _pointerOwnedByHandle = false;
    _isInteractionActive = false;
    _isDirectionRejected = false;
    _initialDirectionAllowsDismissal = null;
    _isReducedMotion = false;
    _isAwaitingDismissal = false;
    _surfaceWasBlockedByScroll = false;
    _velocityTracker = null;
    _pointerDownTimeStamp = null;
    _previousPointerTimeStamp = null;
    _pointerDownPosition = null;
    _previousPointerPosition = null;
    _pointerDeviceKind = null;
    _pointerDx = 0;
    _pointerDy = 0;
    _interactionStartDx = 0;
    _interactionStartDy = 0;
    _isScrollFreezeScheduled = false;
    _isApplyingScrollFreeze = false;
    _releaseActiveScrollHolds();
    for (final source in _frozenScrollSources) {
      source.resetFreeze();
    }
    _frozenScrollSources.clear();
    _activeScrollSources.clear();
    _gestureDragConfig = null;
    _gestureOnOverdrag = null;
    if (_resetScrollMovementAfterGesture) {
      _resetScrollMovementAfterGesture = false;
      _resetScrollMovement();
    }
    if (!keepVisualState) {
      _isCommitted = false;
      _setTranslation(0, 0);
      _restoreStartDx = 0;
      _restoreStartDy = 0;
    }
    _gestureOnPositionChanged = null;
    _gestureDirection = null;
    _childExtent = null;
  }

  bool _handlePointerDown(
    PointerDownEvent event, {
    required bool fromHandle,
  }) {
    if (_activePointer != null || (_restoreController?.isAnimating ?? false) || _isCommitted || _isAwaitingDismissal) {
      return false;
    }
    final pointerKey = (pointer: event.pointer, viewId: event.viewId);
    final pointerOwner = _pointerOwners[pointerKey];
    if (pointerOwner != null && !identical(pointerOwner, this)) return false;
    if (_deniedPointers.contains(pointerKey)) return false;
    // A handle and the surrounding listener can receive the same pointer down.
    _deniedPointers.add(pointerKey);
    try {
      if (!(widget.canStartDrag?.call() ?? true)) return false;
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'oh_my_flutter',
          context: ErrorDescription('while deciding whether to start an interactive swipe drag'),
        ),
      );
      return false;
    }
    _deniedPointers.remove(pointerKey);
    _pointerOwners[pointerKey] = this;
    _ownedPointerKey = pointerKey;
    _gestureGeneration += 1;
    _gestureDirection = widget.direction;
    _gestureDragConfig = widget.dragConfig;
    _gestureOnOverdrag = widget.onOverdrag;
    _gestureOnPositionChanged = widget.onPositionChanged;
    _activePointer = event.pointer;
    _pointerOwnedByHandle = fromHandle;
    _isReducedMotion = MediaQuery.disableAnimationsOf(context);
    _pointerDownTimeStamp = event.timeStamp;
    _previousPointerTimeStamp = event.timeStamp;
    _pointerDownPosition = event.position;
    _previousPointerPosition = event.position;
    _pointerDeviceKind = event.kind;
    _selectScrollSourcesAt(event.position, event.viewId);
    final size = _translationController.childSize;
    final extent = _axis == Axis.vertical ? size?.height : size?.width;
    _childExtent = extent != null && extent.isFinite && extent > 0 ? extent : null;
    _pointerDx = 0;
    _pointerDy = 0;
    _interactionStartDx = 0;
    _interactionStartDy = 0;
    _surfaceWasBlockedByScroll = false;
    _isDirectionRejected = false;
    _initialDirectionAllowsDismissal = null;
    return true;
  }

  void _handlePointerMove(
    PointerMoveEvent event, {
    required bool fromHandle,
    double? deltaDx,
    double? deltaDy,
  }) {
    assert(
      (deltaDx == null) == (deltaDy == null),
      'Accumulated handle deltas must be supplied together.',
    );
    if (_activePointer != event.pointer || _pointerOwnedByHandle != fromHandle) {
      return;
    }
    if (_isDirectionRejected) return;
    final previousTimeStamp = _previousPointerTimeStamp;
    final previousPosition = _previousPointerPosition;
    _previousPointerTimeStamp = event.timeStamp;
    _previousPointerPosition = event.position;
    _pointerDx += deltaDx ?? event.delta.dx;
    _pointerDy += deltaDy ?? event.delta.dy;
    if (_initialDirectionAllowsDismissal == null) {
      final primary = _signedPrimary(_pointerDx, _pointerDy);
      final cross = _crossAxis(_pointerDx, _pointerDy).abs();
      final activated = _hasOverdrag
          ? Offset(_pointerDx, _pointerDy).distance >= _activationDistance
          : primary.abs() >= _activationDistance || cross >= _activationDistance;
      if (activated) _initialDirectionAllowsDismissal = primary > 0 && primary > cross;
    }
    if (!_isInteractionActive) {
      if (!_hasDirectionalIntent()) {
        if (_shouldRejectDirection()) _isDirectionRejected = true;
        return;
      }
      if (!fromHandle && !(_hasOverdrag ? _canStartOverdragFromSurface(event.delta) : _canStartFromSurface)) {
        _surfaceWasBlockedByScroll = true;
        return;
      }
      if (!fromHandle && _surfaceWasBlockedByScroll && !_hasOverdrag && !_moveFavorsDismissal(event)) {
        return;
      }
      _startInteraction(
        event,
        fromHandle: fromHandle,
        previousTimeStamp: previousTimeStamp,
        previousPosition: previousPosition,
      );
    } else {
      _velocityTracker?.addPosition(event.timeStamp, event.position);
    }
    if (!_isReducedMotion) {
      _updateVisualTranslation();
    }
    if (_hasOverdrag) {
      final raw = Offset(_interactionDx, _interactionDy);
      _reportOverdrag((_initialDirectionAllowsDismissal ?? false) ? raw - _dismissalOffset(raw) : raw);
    }
  }

  void _handleHandleGestureRejected(int pointer) {
    if (_activePointer != pointer || !_pointerOwnedByHandle) return;
    _releasePointerOwnership();
    _activePointer = null;
    if (_isInteractionActive) {
      _cancelInteraction();
      return;
    }
    _resetGestureState();
  }

  void _handlePointerUp(
    PointerUpEvent event, {
    required bool fromHandle,
  }) {
    if (_activePointer != event.pointer || _pointerOwnedByHandle != fromHandle) {
      return;
    }
    _releasePointerOwnership();
    if (!_isInteractionActive) {
      _resetGestureState();
      return;
    }
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    _activePointer = null;
    _finishInteraction();
  }

  void _handlePointerCancel(
    PointerCancelEvent event, {
    required bool fromHandle,
  }) {
    if (_activePointer != event.pointer || _pointerOwnedByHandle != fromHandle) {
      return;
    }
    _releasePointerOwnership();
    _activePointer = null;
    if (_isInteractionActive) {
      _cancelInteraction();
      return;
    }
    _resetGestureState();
  }

  double _distanceFromDismissalEdge(ScrollMetrics metrics) {
    if (_usesMinimumScrollEdge(metrics)) {
      return metrics.pixels - metrics.minScrollExtent;
    }
    return metrics.maxScrollExtent - metrics.pixels;
  }

  _InteractiveSwipeDismissScrollSource? _registerScrollSource(
    BuildContext scrollContext,
  ) {
    if (!scrollContext.mounted) return null;
    final cachedSource = _scrollSourceByNotificationContext[scrollContext];
    if (cachedSource != null && cachedSource.isCurrent) {
      return cachedSource;
    }
    final scrollable = Scrollable.maybeOf(scrollContext);
    if (scrollable == null) return null;
    final position = scrollable.position;
    final previousSource = _scrollSourceByScrollable[scrollable];
    if (previousSource != null && identical(previousSource.position, position)) {
      _scrollSourceByNotificationContext[scrollContext] = previousSource;
      return previousSource;
    }
    final source = _InteractiveSwipeDismissScrollSource(
      scrollable: scrollable,
      position: position,
    );
    if (previousSource != null) {
      source
        ..wasAwayFromEdge = previousSource.wasAwayFromEdge
        ..peakDelta = previousSource.peakDelta
        ..flingReachedEdgeAt = previousSource.flingReachedEdgeAt
        ..minimumEdge = previousSource.minimumEdge
        ..maximumEdge = previousSource.maximumEdge;
    }
    _scrollSourceByScrollable[scrollable] = source;
    _scrollSourceByNotificationContext[scrollContext] = source;
    if (previousSource == null) {
      _registeredScrollables.add(WeakReference<ScrollableState>(scrollable));
      _scrollRegistrationsSinceCompaction += 1;
      if (_scrollRegistrationsSinceCompaction >= 32) {
        _scrollRegistrationsSinceCompaction = 0;
        _compactRegisteredScrollables();
      }
    }
    var replacedActiveSource = false;
    for (var index = 0; index < _activeScrollSources.length; index += 1) {
      if (!identical(_activeScrollSources[index].scrollable, scrollable)) {
        continue;
      }
      _activeScrollSources[index] = source;
      replacedActiveSource = true;
    }
    if (replacedActiveSource && _isInteractionActive && !_isReleasingScrollHold) {
      _freezeActiveScrollSources();
    }
    return source;
  }

  void _compactRegisteredScrollables() {
    for (var index = _registeredScrollables.length - 1; index >= 0; index -= 1) {
      final scrollable = _registeredScrollables[index].target;
      if (scrollable == null || !scrollable.mounted) {
        _registeredScrollables.removeAt(index);
      }
    }
  }

  void _selectScrollSourcesAt(Offset position, int viewId) {
    final sourcesByTarget = <HitTestTarget, _InteractiveSwipeDismissScrollSource>{};
    _compactRegisteredScrollables();
    for (final reference in _registeredScrollables) {
      final scrollable = reference.target;
      if (scrollable == null) continue;
      var source = _scrollSourceByScrollable[scrollable];
      if (source == null || !source.isCurrent) {
        source = _InteractiveSwipeDismissScrollSource(
          scrollable: scrollable,
          position: scrollable.position,
        );
        _scrollSourceByScrollable[scrollable] = source;
      }
      if (!_hasOverdrag && source.position.axis != _axis) continue;
      final renderObject = source.renderObject;
      if (renderObject != null && renderObject.attached) {
        sourcesByTarget[renderObject] = source;
      }
    }
    if (sourcesByTarget.isEmpty) {
      _setActiveScrollSources(const <_InteractiveSwipeDismissScrollSource>[]);
      return;
    }
    final result = HitTestResult();
    GestureBinding.instance.hitTestInView(result, position, viewId);
    final selectedSources = <_InteractiveSwipeDismissScrollSource>[];
    for (final entry in result.path) {
      final source = sourcesByTarget[entry.target];
      if (source == null || selectedSources.contains(source)) continue;
      if (_distanceFromDismissalEdge(source.position) > _scrollAwayThreshold) {
        source.wasAwayFromEdge = true;
      }
      if (source.position.pixels - source.position.minScrollExtent > _scrollAwayThreshold) {
        source.minimumEdge.wasAway = true;
      }
      if (source.position.maxScrollExtent - source.position.pixels > _scrollAwayThreshold) {
        source.maximumEdge.wasAway = true;
      }
      selectedSources.add(source);
    }
    _setActiveScrollSources(selectedSources);
  }

  void _setActiveScrollSources(
    List<_InteractiveSwipeDismissScrollSource> sources,
  ) {
    if (_sameScrollSources(_activeScrollSources, sources)) return;
    _scrollFreezeRevision += 1;
    _isScrollFreezeScheduled = false;
    _releaseActiveScrollHolds();
    for (final source in _frozenScrollSources) {
      source.resetFreeze();
    }
    _frozenScrollSources.clear();
    _activeScrollSources
      ..clear()
      ..addAll(sources);
    if (_isInteractionActive && !_isReleasingScrollHold) {
      _freezeActiveScrollSources();
    }
  }

  bool _sameScrollSources(
    List<_InteractiveSwipeDismissScrollSource> first,
    List<_InteractiveSwipeDismissScrollSource> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index += 1) {
      if (!identical(first[index], second[index])) return false;
    }
    return true;
  }

  void _freezeActiveScrollSources() {
    if (_isReleasingScrollHold) return;
    _scrollFreezeRevision += 1;
    _isScrollFreezeScheduled = false;
    _releaseActiveScrollHolds();
    for (final source in _frozenScrollSources) {
      source.resetFreeze();
    }
    _frozenScrollSources.clear();
    for (final source in _activeScrollSources) {
      if (!source.isCurrent) continue;
      final position = source.position;
      source.frozenOffset = position.hasPixels ? position.pixels : null;
      _frozenScrollSources.add(source);
    }
    _holdActiveScrollPositions();
    _scheduleScrollFreezeReconciliation();
  }

  void _clearActiveScrollSources() {
    _scrollFreezeRevision += 1;
    _isScrollFreezeScheduled = false;
    _isApplyingScrollFreeze = false;
    _releaseActiveScrollHolds();
    for (final source in _frozenScrollSources) {
      source.resetFreeze();
    }
    _frozenScrollSources.clear();
    _activeScrollSources.clear();
  }

  void _resetScrollMovement() {
    for (final reference in _registeredScrollables) {
      final scrollable = reference.target;
      if (scrollable != null) {
        _scrollSourceByScrollable[scrollable]?.resetMovement();
      }
    }
  }

  void _trackScrollMovement(
    _InteractiveSwipeDismissScrollSource source,
    ScrollMetrics metrics,
    double delta, {
    required bool isBallistic,
  }) {
    if (_hasOverdrag) {
      source.minimumEdge.track(
        metrics.pixels - metrics.minScrollExtent,
        delta,
        isBallistic: isBallistic,
      );
      source.maximumEdge.track(
        metrics.maxScrollExtent - metrics.pixels,
        delta,
        isBallistic: isBallistic,
      );
    }
    final distance = _distanceFromDismissalEdge(metrics);
    if (distance > _scrollAwayThreshold) {
      source
        ..wasAwayFromEdge = true
        ..flingReachedEdgeAt = null
        ..peakDelta = 0;
      return;
    }
    if (!source.wasAwayFromEdge) return;
    if (delta.abs() > source.peakDelta) source.peakDelta = delta.abs();
    if (distance > _scrollEdgeTolerance) return;
    source.wasAwayFromEdge = false;
    if (isBallistic || source.peakDelta > _fastScrollDeltaThreshold) {
      source.flingReachedEdgeAt = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    }
    source.peakDelta = 0;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final scrollContext = notification.context;
    if (scrollContext == null) return false;
    final source = _registerScrollSource(scrollContext);
    if (source == null || _isReleasingScrollHold || (!_hasOverdrag && notification.metrics.axis != _axis)) {
      return false;
    }
    if (!_isApplyingScrollFreeze && notification is ScrollUpdateNotification) {
      _trackScrollMovement(
        source,
        notification.metrics,
        notification.scrollDelta ?? 0,
        isBallistic: notification.dragDetails == null,
      );
    }
    if (_activeScrollSources.contains(source) &&
        !_isApplyingScrollFreeze &&
        (notification is ScrollStartNotification ||
            notification is ScrollUpdateNotification ||
            notification is OverscrollNotification)) {
      _scheduleScrollFreezeReconciliation();
    }
    return false;
  }

  void _scheduleScrollFreezeReconciliation() {
    if (!_isInteractionActive || _activePointer == null || _isScrollFreezeScheduled || _isApplyingScrollFreeze) {
      return;
    }
    if (_frozenScrollSources.isEmpty) {
      return;
    }
    final sources = List<_InteractiveSwipeDismissScrollSource>.of(
      _frozenScrollSources,
    );
    final generation = _gestureGeneration;
    final revision = _scrollFreezeRevision;
    _isScrollFreezeScheduled = true;
    scheduleMicrotask(() {
      if (revision != _scrollFreezeRevision) return;
      _isScrollFreezeScheduled = false;
      if (!mounted || generation != _gestureGeneration || !_isInteractionActive || _activePointer == null) {
        return;
      }
      _isApplyingScrollFreeze = true;
      try {
        for (final source in sources) {
          if (!source.isCurrent) continue;
          final position = source.position;
          if (!position.hasPixels || !position.hasContentDimensions) continue;
          final frozenOffset = source.frozenOffset ??= position.pixels;
          final clampedOffset = frozenOffset.clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          );
          if (position.pixels != clampedOffset) {
            position.jumpTo(clampedOffset);
          }
        }
        _holdActiveScrollPositions();
      } finally {
        _isApplyingScrollFreeze = false;
      }
    });
  }

  bool _handleScrollMetricsNotification(
    ScrollMetricsNotification notification,
  ) {
    final source = _registerScrollSource(notification.context);
    if (source != null &&
        !_isReleasingScrollHold &&
        (_hasOverdrag || notification.metrics.axis == _axis) &&
        _activeScrollSources.contains(source)) {
      _scheduleScrollFreezeReconciliation();
    }
    return false;
  }

  void _holdActiveScrollPositions() {
    if (_isStartingScrollHold || _isReleasingScrollHold) {
      return;
    }
    _isStartingScrollHold = true;
    try {
      for (final source in _frozenScrollSources) {
        if (source.hold != null || !source.isCurrent) continue;
        source.hold = source.position.hold(() => source.hold = null);
      }
    } finally {
      _isStartingScrollHold = false;
    }
  }

  void _releaseActiveScrollHolds() {
    if (_isReleasingScrollHold) return;
    _isReleasingScrollHold = true;
    try {
      for (final source in _frozenScrollSources) {
        final hold = source.hold;
        if (hold == null) continue;
        source.hold = null;
        hold.cancel();
      }
    } finally {
      _isReleasingScrollHold = false;
    }
  }

  void _releasePointerOwnership() {
    final pointerKey = _ownedPointerKey;
    if (pointerKey == null) return;
    if (identical(_pointerOwners[pointerKey], this)) {
      _pointerOwners.remove(pointerKey);
    }
    _ownedPointerKey = null;
  }

  @override
  void initState() {
    super.initState();
    _coordinator = _InteractiveSwipeDismissCoordinator(this);
  }

  @override
  void didUpdateWidget(InteractiveSwipeDismiss oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.direction == oldWidget.direction) return;
    if (_gestureDirection != null) {
      _resetScrollMovementAfterGesture = true;
      return;
    }
    _resetScrollMovement();
    _clearActiveScrollSources();
  }

  @override
  void dispose() {
    _deniedPointers.clear();
    _isInteractionActive = false;
    _activePointer = null;
    _releasePointerOwnership();
    _releaseActiveScrollHolds();
    _resetScrollMovement();
    _restoreController
      ?..removeListener(_handleRestoreTick)
      ..dispose();
    super.dispose();
  }

  void _handleSurfacePointerDown(PointerDownEvent event) {
    _handlePointerDown(event, fromHandle: false);
  }

  void _handleSurfacePointerMove(PointerMoveEvent event) {
    _handlePointerMove(event, fromHandle: false);
  }

  void _handleSurfacePointerUp(PointerUpEvent event) {
    _deniedPointers.remove((pointer: event.pointer, viewId: event.viewId));
    _handlePointerUp(event, fromHandle: false);
  }

  void _handleSurfacePointerCancel(PointerCancelEvent event) {
    _deniedPointers.remove((pointer: event.pointer, viewId: event.viewId));
    _handlePointerCancel(event, fromHandle: false);
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.dragConfig._debugValidate(), 'Invalid drag configuration.');
    return _InteractiveSwipeDismissScope(
      coordinator: _coordinator,
      child: Listener(
        behavior: HitTestBehavior.deferToChild,
        onPointerDown: _handleSurfacePointerDown,
        onPointerMove: _handleSurfacePointerMove,
        onPointerUp: _handleSurfacePointerUp,
        onPointerCancel: _handleSurfacePointerCancel,
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: _handleScrollMetricsNotification,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: _InteractiveSwipeDismissTranslation(
              controller: _translationController,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
