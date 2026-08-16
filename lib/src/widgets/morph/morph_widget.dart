part of 'morph.dart';

/// Animates a widget between two matching locations.
///
/// Give the source and destination the same [tag]. When the visible location
/// changes, Morph animates the shared content between their positions and
/// sizes.
///
/// Eligible Widgets receive specialized transitions automatically.
/// Other combinations move between their endpoint geometry and
/// switch content at [switchThreshold]. Supply [flightDelegate]
/// only for a custom transition.
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
/// Replacing [child] on the same [Morph] starts an in-place transition. Give
/// the old and new children the same non-null key when a rebuild should update
/// the resting widget without animating. Replacing an unkeyed child starts a
/// transition whenever its widget instance changes.
///
/// When animations are disabled before a transition starts, Morph shows the
/// destination immediately without invoking lifecycle callbacks. If they
/// become disabled during a transition, Morph finishes immediately without
/// invoking [onReceived] or [onEnd]; an earlier [onStart] remains invoked.
class Morph extends StatefulWidget {
  /// Creates a widget that can transition to another [Morph] with the same tag.
  const Morph({
    required this.tag,
    required this.child,
    this.flightDelegate,
    this.duration,
    this.curve,
    this.watchDestination = false,
    this.switchThreshold = 0.5,
    this.switchTransition,
    this.onStart,
    this.onEnd,
    this.onReceived,
    super.key,
  }) : assert(
         switchThreshold >= 0 && switchThreshold <= 1,
         'switchThreshold must be between 0 and 1.',
       );

  static const Duration _defaultDuration = Duration(milliseconds: 300);
  static const Curve _defaultCurve = Curves.linear;

  /// Identifier shared by the source and destination widgets.
  ///
  /// Use a distinct tag for each logical shared element.
  /// Tags match using `Object.==` and `Object.hashCode`. Keep the tag's equality
  /// and hash code stable while this widget is mounted.
  final Object tag;

  /// Widget shown at this location when no transition is running.
  final Widget child;

  /// Optional custom definition of the in-flight visual.
  ///
  /// Leave this null to select the best built-in transition from the paired
  /// endpoint children. Matching endpoints must either both omit this value or
  /// use the same delegate runtime type with the same meaning for its type
  /// parameter. The departing endpoint's delegate controls the transition.
  final MorphFlightDelegate<Object?>? flightDelegate;

  /// Duration of transitions within the same route.
  ///
  /// When omitted, the nearest ancestor Morph's effective duration is used.
  /// If no Morph ancestor supplies one, 300 milliseconds is used.
  ///
  /// When the two widgets use different durations, the source value is used.
  /// Transitions between routes follow the route's duration instead.
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
  /// destination's position or size.
  ///
  /// Set this to true when the matching endpoint can move or resize while a
  /// flight travels from this Morph toward it. The flight then continues
  /// toward the destination's updated geometry instead of its initial
  /// geometry.
  ///
  /// This setting has no effect on flights arriving at this Morph. Set it on
  /// both matching Morphs when each direction's destination can move while the
  /// flight is running.
  final bool watchDestination;

  /// Progress at which automatic transitions switch discrete child values.
  ///
  /// The departing endpoint supplies this value.
  final double switchThreshold;

  /// Transition applied when automatic content changes at [switchThreshold].
  ///
  /// This includes changed Text values, generic widget pairs, and ordinary
  /// content inside eligible widgets. The supplied animation moves from 1 to 0
  /// for departing content and from 0 to 1 for arriving content. Without a
  /// builder, discrete content changes immediately at [switchThreshold].
  /// Nested Morph widgets animate independently. The departing endpoint
  /// supplies this builder.
  final AnimatedSwitcherTransitionBuilder? switchTransition;

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
    final delegate = morph.flightDelegate;
    if (delegate != null) return delegate;
    return _MorphAutomaticFlightDelegate(
      switchThreshold: morph.switchThreshold,
      switchTransition: morph.switchTransition,
    );
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
    );
  }

  _MorphEndpointGeometry? _readLiveGeometry() {
    final renderObject = _renderObject;
    final overlayRenderObject = _overlayRenderObject;
    if (renderObject is! _RenderMorphEndpoint ||
        overlayRenderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize ||
        !overlayRenderObject.attached ||
        !overlayRenderObject.hasSize) {
      return null;
    }

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

  MorphEndpoint<Object?> _resolveEndpoint({
    required _MorphEndpointGeometry geometry,
    required Widget child,
    required MorphFlightDelegate<Object?> flightDelegate,
  }) {
    final capturedTransform = Matrix4.copy(geometry.transform);
    final endpointContext = MorphEndpointContext._(
      context: context,
      child: child,
      internalRenderObject: geometry.renderObject,
      localSize: geometry.localSize,
      overlayBounds: geometry.overlayBounds,
      transform: capturedTransform,
      axisScale: geometry.axisScale,
    );

    final endpoint = MorphEndpoint<Object?>(
      properties: flightDelegate.properties(endpointContext),
      bounds: geometry.overlayBounds,
      localSize: geometry.localSize,
      transform: capturedTransform,
      axisScale: geometry.axisScale,
    );
    final endpointHandle = _endpoint;
    if (endpointHandle != null) {
      _MorphDescendantSnapshots.attach(
        endpoint,
        endpointHandle._captureDescendants(),
      );
    }
    return endpoint;
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
      visibility: _visibility,
      overlay: overlay,
      route: route,
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
    route?.animation?.addStatusListener(_handleRouteStatus);
  }

  void _detach() {
    _route?.animation?.removeStatusListener(_handleRouteStatus);
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

  void _handleRouteStatus(AnimationStatus status) {
    final endpoint = _endpoint;
    if (endpoint == null || status != AnimationStatus.reverse) return;
    _MorphCoordinator.of(endpoint.overlay).startRoutePop(endpoint);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_MorphFlightScope.contains(context)) {
      _detach();
      return;
    }
    _attach();
  }

  @override
  void didUpdateWidget(Morph oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldDelegate = _resolvedFlightDelegate;
    _resolvedFlightDelegate = _resolveFlightDelegate(widget);
    if (oldWidget.tag == widget.tag && oldDelegate.runtimeType == _resolvedFlightDelegate.runtimeType) {
      final endpoint = _endpoint;
      final oldDuration = endpoint?.duration ?? oldWidget.duration ?? Morph._defaultDuration;
      final oldCurve = endpoint?.curve ?? oldWidget.curve ?? Morph._defaultCurve;
      endpoint?.configurationChanged();
      final oldChildKey = oldWidget.child.key;
      final newChildKey = widget.child.key;
      final representsNewOwnership =
          !identical(oldWidget.child, widget.child) &&
          (oldChildKey == null || newChildKey == null || oldChildKey != newChildKey);
      if (endpoint != null && representsNewOwnership) {
        _MorphCoordinator.of(endpoint.overlay).replaceFromState(
          endpoint,
          sourceCapture: () => _capture(
            child: oldWidget.child,
            flightDelegate: oldDelegate,
          ),
          sourceIdentity: oldChildKey ?? oldWidget.child,
          destinationIdentity: newChildKey ?? widget.child,
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

    _detach();
    _attach();
  }

  @override
  void deactivate() {
    final endpoint = _endpoint;
    if (endpoint != null) {
      _MorphCoordinator.of(endpoint.overlay).deactivate(endpoint);
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    final endpoint = _endpoint;
    if (endpoint != null) {
      _MorphCoordinator.of(endpoint.overlay).activate(endpoint);
    }
  }

  @override
  void dispose() {
    _detach();
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_MorphFlightScope.contains(context)) {
      return TickerMode(
        enabled: false,
        child: Opacity(opacity: 0, child: widget.child),
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
      duration: endpoint.duration,
      curve: endpoint.curve,
      child: endpointBoundary,
    );
  }
}
