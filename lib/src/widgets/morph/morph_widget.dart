part of 'morph.dart';

/// Animates a widget between two matching locations.
///
/// Give each appearance a stable [MorphTarget] with the same tag. Mounting a
/// new appearance moves the shared visual to it; removing it returns to the
/// most recently mounted appearance that remains. Rebuilds do not reorder
/// appearances. A covered appearance cannot start a child-replacement flight.
///
/// Register a stable [MorphNavigatorObserver] from the creation of each
/// Navigator containing Morphs. Local transitions also work in a standalone
/// Overlay. Without an Overlay, [child] renders normally without transitions.
///
/// Eligible Widgets receive specialized transitions automatically.
/// Other combinations move between their endpoint geometry and switch content
/// halfway through. Configure [flightConfig] to change child replacement or
/// supply a custom transition.
///
/// Generic transitions preserve inherited themes and MediaQuery values. They
/// do not preserve other inherited values introduced locally around an
/// endpoint. A live in-flight subtree must not contain GlobalKeys that are also
/// mounted at an endpoint. Use [MorphDescendant] with
/// [MorphDescendantFlightBehavior.snapshot] or
/// [MorphDescendantFlightBehavior.hide] to keep such a subtree at its resting
/// endpoint, or use a custom delegate when it must have a different in-flight
/// visual.
///
/// When [animateChildChanges] is true, replacing [child] on the same [Morph]
/// starts an in-place transition. Give the old and new children the same
/// non-null key when a rebuild should update
/// the resting widget without animating. Replacing an unkeyed child starts a
/// transition whenever its widget instance changes.
///
/// When animations are disabled before a transition starts, Morph shows the
/// destination immediately without invoking lifecycle callbacks. If they
/// become disabled during a transition, Morph finishes immediately without
/// invoking [onReceived] or [onEnd]; an earlier [onStart] remains invoked.
///
/// See the [Morph guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph.md)
/// for endpoint setup, automatic transitions, and customization.
class Morph extends StatefulWidget {
  /// Creates an appearance that can transition to another with an equal tag.
  const Morph({
    required this.target,
    required this.child,
    this.flightConfig = const MorphFlightConfig.auto(),
    this.duration,
    this.curve,
    this.watchDestination = false,
    this.animateChildChanges = false,
    this.onStart,
    this.onEnd,
    this.onReceived,
    super.key,
  });

  static const Duration _defaultDuration = Duration(milliseconds: 300);
  static const Curve _defaultCurve = Curves.linear;

  static bool _debugValidateDuration(Duration? duration) {
    assert(
      duration == null || !duration.isNegative,
      'duration must not be negative.',
    );
    return true;
  }

  /// Identifier shared by the source, destination and sibling widgets.
  ///
  /// Use a distinct target object for each logical shared element. At most one Morph
  /// may use a target at a time. Keep the target's equality and hash code
  /// stable while this widget is mounted.
  final MorphTarget target;

  /// Widget shown at this location when no transition is running.
  final Widget child;

  /// Whether replacing [child] can start an in-place transition.
  ///
  /// Defaults to false. When enabled, a different child instance starts a
  /// transition unless both children have the same non-null key. Rebuilds within the existing
  /// child subtree do not start a transition.
  ///
  /// Set this to false to update the child without a replacement transition.
  /// Matching appearances still transition when mounted, removed, or replaced,
  /// including during navigation. This does not cancel an existing flight.
  /// The new value applies when this property and [child] change together.
  final bool animateChildChanges;

  /// How the shared element appears during its transition.
  ///
  /// Defaults to [MorphFlightConfig.auto], which selects an automatic
  /// visual for the paired children. Configure that constructor to change when
  /// child content switches and how it disappears and appears.
  ///
  /// Use [MorphFlightConfig.custom] for a custom visual. Matching
  /// endpoints must both use automatic configuration or compatible custom
  /// delegates. The departing endpoint's configuration controls the transition.
  final MorphFlightConfig flightConfig;

  /// Duration of transitions started by this Morph.
  ///
  /// When omitted, the nearest ancestor Morph's configured duration is used.
  /// If no Morph ancestor supplies one, transitions within the same route use
  /// 300 milliseconds and transitions between routes follow the route's
  /// animation.
  ///
  /// When the two widgets use different durations, the source value is used.
  /// The duration must not be negative. [Duration.zero] completes the visual
  /// transition immediately.
  ///
  /// When several Morph transitions start together, shorter transitions remain
  /// visually settled while the other transitions finish.
  final Duration? duration;

  /// Curve applied while moving from the source to the destination.
  ///
  /// When omitted, the nearest ancestor Morph's effective curve is used. If no
  /// Morph ancestor supplies one, [Curves.linear] is used.
  ///
  /// When the two widgets use different curves, the source value is used.
  ///
  /// Curves that overshoot may produce progress outside the 0 to 1 interval.
  final Curve? curve;

  /// Whether a flight departing from this Morph follows changes to its
  /// destination's geometry and snapshotted descendants.
  ///
  /// Set this to true when the matching endpoint can move or resize while a
  /// flight travels from this Morph toward it. The flight then continues
  /// toward the destination's updated geometry instead of its initial
  /// geometry. Descendants using
  /// [MorphDescendantFlightBehavior.snapshot] also refresh their destination
  /// image and size when they change, without mounting another copy of their
  /// subtree.
  ///
  /// This setting has no effect on flights arriving at this Morph. Set it on
  /// both matching Morphs when each direction's destination can move while the
  /// flight is running.
  final bool watchDestination;

  /// Called on the source when its transition starts.
  final VoidCallback? onStart;

  /// Called on the source after the transition reaches the destination.
  final VoidCallback? onEnd;

  /// Called on the destination immediately before the source's [onEnd].
  final VoidCallback? onReceived;

  @override
  State<Morph> createState() => _MorphState();
}

class _MorphState extends State<Morph> {
  _MorphVisibilityHandle _visibility = _MorphVisibilityHandle();
  _MorphEndpointHandle? _endpoint;
  MorphTarget? _attachedTarget;
  OverlayState? _overlay;
  ModalRoute<Object?>? _route;
  _RenderMorphEndpoint? _renderObject;
  RenderBox? _overlayRenderObject;
  List<RenderObject>? _transformPath;
  _MorphEndpointGeometry? _geometryScratch;
  _MorphEndpointGeometry? _lastPaintedGeometry;
  Widget? _lastPaintedChild;
  MorphFlightDelegate<Object?>? _lastPaintedFlightDelegate;
  late MorphFlightDelegate<Object?> _resolvedFlightDelegate;

  @override
  void initState() {
    super.initState();
    _resolvedFlightDelegate = _resolveFlightDelegate(widget);
  }

  MorphFlightDelegate<Object?> _resolveFlightDelegate(Morph morph) {
    return switch (morph.flightConfig) {
      _MorphAutoFlightConfiguration(:final childSwitchAt, :final childTransition) => _MorphAutomaticFlightDelegate(
        switchThreshold: childSwitchAt,
        switchTransition: childTransition,
      ),
      _MorphCustomFlightConfiguration(:final delegate) => delegate,
    };
  }

  MorphEndpoint<Object?>? _capture({
    Widget? child,
    MorphFlightDelegate<Object?>? flightDelegate,
  }) {
    final geometry = _readLiveGeometry();
    if (geometry == null) return null;
    return _resolveEndpoint(
      geometry: geometry,
      child: child ?? widget.child,
      flightDelegate: flightDelegate ?? _resolvedFlightDelegate,
    );
  }

  MorphEndpoint<Object?>? _captureLastPainted() {
    final overlayRenderObject = _overlayRenderObject;
    final geometry = _lastPaintedGeometry;
    final child = _lastPaintedChild;
    final flightDelegate = _lastPaintedFlightDelegate;
    if (overlayRenderObject == null ||
        !overlayRenderObject.attached ||
        geometry == null ||
        child == null ||
        flightDelegate == null) {
      return null;
    }
    return _resolveEndpoint(
      geometry: geometry,
      child: child,
      flightDelegate: flightDelegate,
      allowDetachedDescendants: true,
    );
  }

  _MorphEndpointGeometry? _readLiveGeometry() {
    final renderObject = _renderObject;
    final overlayRenderObject = _overlayRenderObject ?? _overlay?.context.findRenderObject();
    if (renderObject is! _RenderMorphEndpoint ||
        overlayRenderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize ||
        !overlayRenderObject.attached ||
        !overlayRenderObject.hasSize) {
      return null;
    }
    _overlayRenderObject = overlayRenderObject;

    final childRenderObject = renderObject.child;
    if (childRenderObject == null || !childRenderObject.hasSize) return null;

    final path = _validatedTransformPath(
      renderObject: renderObject,
      overlayRenderObject: overlayRenderObject,
    );
    if (path == null) return null;

    final scratch = _geometryScratch ??= _MorphEndpointGeometry(
      renderObject: childRenderObject,
      localSize: renderObject.size,
      overlayBounds: Rect.zero,
      transform: Matrix4.identity(),
      axisScale: Offset.zero,
    );
    final transform = scratch.transform..setIdentity();
    for (var index = path.length - 1; index > 0; index -= 1) {
      path[index].applyPaintTransform(path[index - 1], transform);
    }
    final bounds = MatrixUtils.transformRect(
      transform,
      Offset.zero & renderObject.size,
    );
    if (!bounds.isFinite || bounds.isEmpty) return null;

    final values = transform.storage;
    final scaleX = math.sqrt((values[0] * values[0]) + (values[1] * values[1]));
    final scaleY = math.sqrt((values[4] * values[4]) + (values[5] * values[5]));
    scratch
      ..renderObject = childRenderObject
      ..localSize = renderObject.size
      ..overlayBounds = bounds
      ..axisScale = Offset(scaleX, scaleY);
    return scratch;
  }

  List<RenderObject>? _validatedTransformPath({
    required _RenderMorphEndpoint renderObject,
    required RenderBox overlayRenderObject,
  }) {
    final cachedPath = _transformPath;
    if (cachedPath != null &&
        cachedPath.isNotEmpty &&
        identical(cachedPath.first, renderObject) &&
        identical(cachedPath.last, overlayRenderObject)) {
      var valid = true;
      for (var index = 0; index < cachedPath.length; index += 1) {
        final node = cachedPath[index];
        if (node case final RenderBox box when !box.hasSize) {
          valid = false;
          break;
        }
        if (index + 1 < cachedPath.length && !identical(node.parent, cachedPath[index + 1])) {
          valid = false;
          break;
        }
      }
      if (valid) return cachedPath;
    }

    final path = (cachedPath ?? <RenderObject>[])..clear();
    RenderObject? node = renderObject;
    while (node != null) {
      if (node case final RenderBox box when !box.hasSize) return null;
      path.add(node);
      if (identical(node, overlayRenderObject)) {
        _transformPath = path;
        return path;
      }
      node = node.parent;
    }
    return null;
  }

  void _rememberPaintedGeometry() {
    final geometry = _readLiveGeometry();
    if (geometry == null) return;
    final lastPaintedGeometry = _lastPaintedGeometry;
    if (lastPaintedGeometry == null) {
      _lastPaintedGeometry = _MorphEndpointGeometry(
        renderObject: geometry.renderObject,
        localSize: geometry.localSize,
        overlayBounds: geometry.overlayBounds,
        transform: geometry.transform,
        axisScale: geometry.axisScale,
      );
    } else {
      lastPaintedGeometry.updateFrom(geometry);
    }
    _lastPaintedChild = widget.child;
    _lastPaintedFlightDelegate = _resolvedFlightDelegate;
  }

  void _rememberPresentation() {
    final endpoint = _endpoint;
    if (endpoint == null || !endpoint.active || endpoint.disposed || !endpoint.presentationRequested) {
      return;
    }
    endpoint.presentationGeneration += 1;
    _MorphCoordinator.of(endpoint.overlay).endpointPresented(endpoint);
  }

  void _requestPresentation() {
    _renderObject?.markNeedsPaint();
  }

  MorphEndpoint<Object?> _resolveEndpoint({
    required _MorphEndpointGeometry geometry,
    required Widget child,
    required MorphFlightDelegate<Object?> flightDelegate,
    bool allowDetachedDescendants = false,
  }) {
    final capturedTransform = Matrix4.copy(geometry.transform);
    final descendantCapture = _MorphDescendantCapture();
    final endpointContext = MorphEndpointContext._(
      context: context,
      child: child,
      internalRenderObject: geometry.renderObject,
      localSize: geometry.localSize,
      overlayBounds: geometry.overlayBounds,
      transform: capturedTransform,
      axisScale: geometry.axisScale,
      descendantCapture: descendantCapture,
    );

    final Object? properties;
    try {
      properties = flightDelegate.properties(endpointContext);
    } finally {
      descendantCapture.acceptsRegistrations = false;
    }
    final endpoint = MorphEndpoint<Object?>(
      properties: properties,
      bounds: geometry.overlayBounds,
      localSize: geometry.localSize,
      transform: capturedTransform,
      axisScale: geometry.axisScale,
    );
    if (descendantCapture.hasRegistrations) {
      descendantCapture.replaceRecords(
        _endpoint?._captureDescendants(allowDetached: allowDetachedDescendants) ?? const [],
      );
      _MorphDescendantSnapshots.attach(endpoint, capture: descendantCapture);
    }
    return endpoint;
  }

  void _attachTarget() {
    if (_MorphFlightScope.contains(context)) {
      _detachTarget();
      return;
    }
    if (identical(_attachedTarget, widget.target)) return;
    _detachTarget();
    widget.target._attach(this);
    _attachedTarget = widget.target;
  }

  void _detachTarget() {
    _attachedTarget?._detach(this);
    _attachedTarget = null;
  }

  void _attach() {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      _detach();
      return;
    }

    final route = ModalRoute.of(context);
    final parentEndpoint = _MorphEndpointScope.maybeOf(context);
    if (identical(_overlay, overlay) && identical(_route, route) && _endpoint != null) {
      _endpoint!.parentEndpoint = parentEndpoint;
      _MorphCoordinator.of(overlay).configurationChanged(_endpoint!);
      return;
    }

    _detach();
    _overlay = overlay;
    _route = route;
    final endpoint = _MorphEndpointHandle(
      owner: this,
      target: widget.target,
      visibility: _visibility,
      overlay: overlay,
      route: route,
      observer: MorphNavigatorObserver._of(context),
      parentEndpoint: parentEndpoint,
    );
    _endpoint = endpoint;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_endpoint, endpoint) || !endpoint.active || endpoint.disposed) {
        return;
      }
      final overlayRenderObject = overlay.context.findRenderObject();
      if (overlayRenderObject is! RenderBox) return;
      _overlayRenderObject = overlayRenderObject;
      _rememberPaintedGeometry();
    });
    _MorphCoordinator.of(overlay).register(endpoint);
  }

  void _detach() {
    final endpoint = _endpoint;
    if (endpoint != null) {
      _MorphCoordinator.of(endpoint.overlay).unregister(endpoint);
      if (identical(_visibility, endpoint.visibility)) {
        _visibility = _MorphVisibilityHandle();
      }
    }
    _endpoint = null;
    _overlay = null;
    _route = null;
    _renderObject = null;
    _overlayRenderObject = null;
    _transformPath = null;
    _geometryScratch = null;
    _lastPaintedGeometry = null;
    _lastPaintedChild = null;
    _lastPaintedFlightDelegate = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_MorphFlightScope.contains(context)) {
      _detachTarget();
      _detach();
      return;
    }
    _attachTarget();
    _attach();
  }

  @override
  void didUpdateWidget(Morph oldWidget) {
    super.didUpdateWidget(oldWidget);
    _attachTarget();
    final oldDelegate = _resolvedFlightDelegate;
    _resolvedFlightDelegate = _resolveFlightDelegate(widget);
    if (identical(oldWidget.target, widget.target) && oldDelegate.runtimeType != _resolvedFlightDelegate.runtimeType) {
      final endpoint = _endpoint;
      if (endpoint != null) {
        endpoint.configurationChanged();
        final coordinator = _MorphCoordinator.of(endpoint.overlay);
        if (identical(coordinator._groups[endpoint.tag]?.selected?.target, endpoint.target)) {
          coordinator._transferOwnershipImmediately(endpoint);
        }
      }
      return;
    }
    if (identical(oldWidget.target, widget.target) && oldDelegate.runtimeType == _resolvedFlightDelegate.runtimeType) {
      final endpoint = _endpoint;
      final oldDuration = endpoint?.duration ?? oldWidget.duration ?? Morph._defaultDuration;
      final oldCurve = endpoint?.curve ?? oldWidget.curve ?? Morph._defaultCurve;
      endpoint?.configurationChanged();
      if (endpoint != null) {
        _MorphCoordinator.of(endpoint.overlay)._scheduleStructuralOrderRefresh();
      }
      final oldChildKey = oldWidget.child.key;
      final newChildKey = widget.child.key;
      final representsNewOwnership =
          !identical(oldWidget.child, widget.child) &&
          (oldChildKey == null || newChildKey == null || oldChildKey != newChildKey);
      if (widget.animateChildChanges && endpoint != null && representsNewOwnership) {
        _MorphCoordinator.of(endpoint.overlay).replaceFromState(
          endpoint,
          sourceCapture: () => _capture(
            child: oldWidget.child,
            flightDelegate: oldDelegate,
          ),
          sourceIdentity: (widget.target, oldChildKey ?? oldWidget.child),
          destinationIdentity: (widget.target, newChildKey ?? widget.child),
          sourceDelegate: oldDelegate,
          duration: oldDuration,
          curve: oldCurve,
          watchDestination: oldWidget.watchDestination,
          onStart: oldWidget.onStart,
          onEnd: oldWidget.onEnd,
        );
      }
      return;
    }

    final departing = _endpoint;
    if (departing != null) {
      _MorphCoordinator.of(departing.overlay)._captureDeparture(departing);
    }
    _detach();
    _attach();
  }

  @override
  void deactivate() {
    _attachedTarget?._detach(this);
    final endpoint = _endpoint;
    if (endpoint != null) {
      _MorphCoordinator.of(endpoint.overlay).deactivate(endpoint);
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _attachedTarget?._attach(this);
    final endpoint = _endpoint;
    if (endpoint != null) {
      _MorphCoordinator.of(endpoint.overlay).activate(endpoint);
    }
  }

  @override
  void dispose() {
    _detachTarget();
    _detach();
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flightScope = _MorphFlightScope.scopeOf(context);
    if (flightScope != null) {
      final hiddenByFlight = flightScope.hasFlight(widget.target.tag);
      return _MorphDescendantFlightScope(
        flightScope: flightScope,
        resolver: null,
        child: hiddenByFlight
            ? TickerMode(enabled: false, child: Opacity(opacity: 0, child: widget.child))
            : widget.child,
      );
    }
    final visibility = _visibility;
    final parentTickersEnabled = TickerMode.valuesOf(context).enabled;
    final endpointBoundary = _MorphEndpointBoundary(
      visibility: visibility,
      onRenderObjectReady: (renderObject) {
        if (!identical(_renderObject, renderObject)) {
          _transformPath = null;
        }
        _renderObject = renderObject;
      },
      onPaint: _rememberPaintedGeometry,
      onPresented: _rememberPresentation,
      child: ValueListenableBuilder<bool>(
        valueListenable: visibility.tickersEnabled,
        builder: (context, tickersEnabled, child) {
          return TickerMode(
            enabled: parentTickersEnabled && tickersEnabled && !visibility.hidden,
            child: child!,
          );
        },
        child: widget.child,
      ),
    );
    final endpoint = _endpoint;
    if (endpoint == null) return endpointBoundary;
    return _MorphEndpointScope(
      endpoint: endpoint,
      configuredDuration: endpoint.configuredDuration,
      duration: endpoint.duration,
      curve: endpoint.curve,
      child: endpointBoundary,
    );
  }
}
