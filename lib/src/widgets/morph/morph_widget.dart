part of 'morph.dart';

/// Animates a widget between two matching locations.
///
/// Share one stable [MorphTarget] instance between matching appearances.
/// Mounting a new appearance moves the shared visual to it; removing it returns to the
/// most recently mounted appearance that remains. Rebuilds do not reorder
/// appearances. Updating [child] does not start a transition.
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
/// When animations are disabled before a transition starts, Morph shows the
/// destination immediately without invoking lifecycle callbacks. If they
/// become disabled during a transition, Morph finishes immediately without
/// invoking [onReceived] or [onEnd]; an earlier [onStart] remains invoked.
///
/// See the [Morph guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph.md)
/// for endpoint setup, automatic transitions, and customization.
class Morph extends StatefulWidget {
  /// Creates an appearance that can transition to another sharing a target.
  const new({
    required this.targets,
    required this.child,
    this.flightConfig = const MorphFlightConfig.auto(),
    this.canMatch,
    this.onStart,
    this.onEnd,
    this.onReceived,
    super.key,
  });

  static const Duration _defaultDuration = Duration(milliseconds: 300);
  static const Curve _defaultCurve = Curves.linear;

  /// Ordered alternatives for matching this visual with another appearance.
  ///
  /// The destination's first usable match wins. One visual can join only one
  /// flight at a time. Supply a nonempty list of distinct targets, keep the
  /// target instances stable, and do not mutate the list.
  final List<MorphTarget> targets;

  /// Restricts which connections this appearance may use.
  ///
  /// Use this to accept different alternatives at different locations while
  /// sharing the same targets. The shared [MorphTarget.canMatch] runs first,
  /// followed by the destination's predicate and then the source's predicate.
  /// All must approve. Rejection tries the destination's next target.
  ///
  /// Keep this synchronous and side-effect-free. An accepted flight retains
  /// its decision through completion, cancellation, and interruption. Policy
  /// changes alone do not start or cancel a flight. Exceptions are reported
  /// through FlutterError and reject the candidate.
  final bool Function(MorphTarget target, MorphMatchContext match)? canMatch;

  /// Widget shown at this location when no transition is running.
  final Widget child;

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
  bool _scopeEnabled = true;
  _MorphVisibilityHandle _visibility = _MorphVisibilityHandle();
  _MorphEndpointHandle? _endpoint;
  List<MorphTarget> _attachedTargets = const [];
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
  _MorphCapturedEnvironment? _capturedEnvironment;

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
    required MorphTarget target,
    Widget? child,
    MorphFlightDelegate<Object?>? flightDelegate,
  }) {
    final geometry = _readSettledLiveGeometry();
    if (geometry == null) return null;
    return _resolveEndpoint(
      target: target,
      geometry: geometry,
      child: child ?? widget.child,
      flightDelegate: flightDelegate ?? _resolvedFlightDelegate,
    );
  }

  _MorphEndpointGeometry? _readSettledLiveGeometry() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == .idle || phase == .postFrameCallbacks) {
      // Post-frame observers can invalidate layout before capture runs. Paint
      // skips dirty render objects, so resolve their layout before measuring
      // or rasterizing the endpoint. Never re-enter the active frame pipeline.
      _renderObject?.owner
        ?..flushLayout()
        ..flushCompositingBits();
    }
    return _readLiveGeometry();
  }

  MorphEndpoint<Object?>? _captureWatchedEndpoint({
    required MorphTarget target,
    required _MorphEndpointGeometry geometry,
    required List<_MorphDescendantFlightRecord> previousRecords,
    required bool pixelRatioChanged,
  }) {
    return _resolveEndpoint(
      target: target,
      geometry: geometry,
      child: widget.child,
      flightDelegate: _resolvedFlightDelegate,
      previousRecords: previousRecords,
      pixelRatioChanged: pixelRatioChanged,
    );
  }

  MorphEndpoint<Object?>? _captureLastPainted({
    required MorphTarget target,
    List<_MorphDescendantFlightRecord>? departureRecords,
    int? departureDescendantRevision,
  }) {
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
      target: target,
      geometry: geometry,
      child: child,
      flightDelegate: flightDelegate,
      allowDetachedDescendants: true,
      departureRecords: departureRecords,
      departureDescendantRevision: departureDescendantRevision,
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

    final scratch = _geometryScratch ??= _MorphEndpointGeometry(
      renderObject: childRenderObject,
      localSize: renderObject.size,
      overlayBounds: Rect.zero,
      transform: Matrix4.identity(),
      axisScale: Offset.zero,
    );
    final transform = scratch.transform;
    if (!_resolveTransformPath(
      renderObject: renderObject,
      overlayRenderObject: overlayRenderObject,
      transform: transform,
    )) {
      return null;
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

  bool _resolveTransformPath({
    required _RenderMorphEndpoint renderObject,
    required RenderBox overlayRenderObject,
    required Matrix4 transform,
  }) {
    final cachedPath = _transformPath;
    if (cachedPath != null &&
        cachedPath.isNotEmpty &&
        identical(cachedPath.first, renderObject) &&
        identical(cachedPath.last, overlayRenderObject)) {
      transform.setIdentity();
      for (var index = cachedPath.length - 1; index > 0; index -= 1) {
        final parent = cachedPath[index];
        final child = cachedPath[index - 1];
        if ((parent is RenderBox && !parent.hasSize) ||
            (child is RenderBox && !child.hasSize) ||
            !identical(child.parent, parent)) {
          break;
        }
        parent.applyPaintTransform(child, transform);
        if (index == 1) return true;
      }
    }

    final path = (cachedPath ?? <RenderObject>[])..clear();
    RenderObject? node = renderObject;
    while (node != null) {
      if (node case final RenderBox box when !box.hasSize) return false;
      path.add(node);
      if (identical(node, overlayRenderObject)) {
        _transformPath = path;
        transform.setIdentity();
        for (var index = path.length - 1; index > 0; index -= 1) {
          path[index].applyPaintTransform(path[index - 1], transform);
        }
        return true;
      }
      node = node.parent;
    }
    return false;
  }

  bool _groupCaptureScheduled = false;

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
    final endpoint = _endpoint;
    if (endpoint?._cachedGroupCapture != null &&
        !endpoint!._cachedGroupCapture!.groupsAreCurrent &&
        !_groupCaptureScheduled &&
        !_visibility.hidden) {
      _groupCaptureScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _groupCaptureScheduled = false;
        final cachedGroupCapture = endpoint._cachedGroupCapture;
        if (mounted &&
            identical(_endpoint, endpoint) &&
            endpoint.active &&
            !endpoint.disposed &&
            !endpoint.visibility.hidden &&
            cachedGroupCapture != null &&
            !cachedGroupCapture.groupsAreCurrent) {
          _MorphCoordinator.of(endpoint.overlay)._capture(endpoint);
        }
      });
    }
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

  MorphEndpoint<Object?>? _resolveEndpoint({
    required MorphTarget target,
    required _MorphEndpointGeometry geometry,
    required Widget child,
    required MorphFlightDelegate<Object?> flightDelegate,
    bool allowDetachedDescendants = false,
    List<_MorphDescendantFlightRecord>? departureRecords,
    int? departureDescendantRevision,
    List<_MorphDescendantFlightRecord>? previousRecords,
    bool pixelRatioChanged = false,
  }) {
    final capturedTransform = Matrix4.copy(geometry.transform);
    final descendantCapture = _MorphDescendantCapture();
    final endpointContext = MorphEndpointContext._(
      target: target,
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
    if (!descendantCapture.groupsReady) return null;
    final endpoint = MorphEndpoint<Object?>(
      properties: properties,
      bounds: geometry.overlayBounds,
      localSize: geometry.localSize,
      transform: capturedTransform,
      axisScale: geometry.axisScale,
    );
    if (descendantCapture.hasRegistrations) {
      final descendantHandle = _endpoint;
      final reusableDepartureRecords =
          departureRecords != null &&
              descendantHandle?.descendantRevision == departureDescendantRevision &&
              departureRecords.every((record) => record.snapshotRevision == record.handle.snapshotRevision)
          ? departureRecords
          : null;
      final records =
          reusableDepartureRecords ??
          (previousRecords == null
              ? _endpoint?._captureDescendants(allowDetached: allowDetachedDescendants) ?? const []
              : _endpoint?._refreshDescendants(
                  previousRecords: previousRecords,
                  pixelRatioChanged: pixelRatioChanged,
                ));
      if (records == null) return null;
      descendantCapture.replaceRecords(records);
      _MorphDescendantSnapshots.attach(endpoint, capture: descendantCapture);
    }
    return endpoint;
  }

  void _attachTargets() {
    assert(widget.targets.isNotEmpty, 'Morph.targets must not be empty.');
    assert(
      widget.targets.toSet().length == widget.targets.length,
      'Morph.targets must contain distinct target instances.',
    );
    if (_MorphFlightScope.contains(context)) {
      _detachTargets();
      return;
    }
    _attachedTargets = List.unmodifiable(widget.targets);
  }

  void _detachTargets() {
    _attachedTargets = const [];
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
      targets: _attachedTargets,
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
    final previousEndpoint = _endpoint;
    context.visitAncestorElements((element) {
      if (element is InheritedElement && element.widget is InheritedTheme) {
        context.dependOnInheritedElement(element);
      }
      return true;
    });
    _capturedEnvironment = _MorphCapturedEnvironment._(context);
    // Preserve inherited themes before a departing element loses its ancestry.
    _capturedEnvironment!
      ..capturedThemes
      ..mediaQueryData;
    _scopeEnabled = _MorphScope.enabledOf(context);
    if (_MorphFlightScope.contains(context)) {
      _detachTargets();
      _detach();
      return;
    }
    _attachTargets();
    _attach();
    if (identical(previousEndpoint, _endpoint)) {
      _endpoint?.captureChanged();
    }
  }

  @override
  void didUpdateWidget(Morph oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousTargets = _attachedTargets;
    _attachTargets();
    final retainsTarget = _endpoint == null || _attachedTargets.contains(_endpoint!.target);
    final replacesAppearance = !previousTargets.any(_attachedTargets.contains);
    if (!replacesAppearance && !listEquals(previousTargets, _attachedTargets) && _endpoint != null) {
      _MorphCoordinator.of(_endpoint!.overlay).updateTargets(_endpoint!, _attachedTargets);
    }
    final oldDelegate = _resolvedFlightDelegate;
    _resolvedFlightDelegate = _resolveFlightDelegate(widget);
    _endpoint?.captureChanged();
    if (retainsTarget && oldDelegate.runtimeType != _resolvedFlightDelegate.runtimeType) {
      final endpoint = _endpoint;
      if (endpoint != null) {
        endpoint.configurationChanged();
        final coordinator = _MorphCoordinator.of(endpoint.overlay);
        if (identical(coordinator._groups[endpoint.tag]?.selected, endpoint)) {
          coordinator._transferOwnershipImmediately(endpoint);
        }
      }
      return;
    }
    if (retainsTarget && oldDelegate.runtimeType == _resolvedFlightDelegate.runtimeType) {
      _endpoint?.configurationChanged();
      if (_endpoint case final endpoint?) {
        _MorphCoordinator.of(endpoint.overlay)._scheduleStructuralOrderRefresh();
      }
      return;
    }

    if (replacesAppearance) {
      final departing = _endpoint;
      if (departing != null) _MorphCoordinator.of(departing.overlay)._captureDeparture(departing);
      _detach();
      _attach();
    } else {
      _endpoint?.configurationChanged();
    }
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
    _detachTargets();
    _detach();
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flightScope = _MorphFlightScope.scopeOf(context);
    if (flightScope != null) {
      final hiddenByFlight = widget.targets.any(flightScope.hasFlight);
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
      onSnapshotSuppressed: _invalidatePresentation,
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

  void _invalidatePresentation() {
    final endpoint = _endpoint;
    if (endpoint == null || !endpoint.active || endpoint.disposed) return;
    _MorphCoordinator.of(endpoint.overlay).endpointPresentationInvalidated(endpoint);
  }
}
