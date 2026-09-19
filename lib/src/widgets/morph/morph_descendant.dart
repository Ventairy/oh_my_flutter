part of 'morph.dart';

/// Configures how [child] participates in its nearest ancestor [Morph].
///
/// Use this widget to customize one descendant subtree relative to the Morph
/// that contains it. Each property controls one aspect of that relationship;
/// for example, [flightBehavior] controls how the subtree is represented while
/// its Morph transitions.
///
/// The configuration applies at any depth beneath a Morph and only to the
/// nearest Morph when Morphs are nested. Outside a Morph, this widget simply
/// renders [child].
class MorphDescendant extends StatefulWidget {
  /// Creates configuration for [child] relative to its nearest ancestor Morph.
  const new({
    required this.flightBehavior,
    required this.child,
    super.key,
  });

  /// How [child] is represented while the nearest ancestor Morph transitions.
  ///
  /// Content without a MorphDescendant uses
  /// [MorphDescendantFlightBehavior.live].
  ///
  /// A non-live behavior also governs non-live MorphDescendants nested inside
  /// [child]. Wrap independent subtrees separately instead of nesting those
  /// boundaries.
  final MorphDescendantFlightBehavior flightBehavior;

  /// The subtree configured relative to its nearest ancestor Morph.
  final Widget child;

  @override
  State<MorphDescendant> createState() => _MorphDescendantState();
}

class _MorphDescendantState extends State<MorphDescendant> {
  late final _MorphDescendantHandle _handle = _MorphDescendantHandle(owner: this);
  _MorphEndpointHandle? _endpoint;
  _MorphDescendantFlightResolver? _flightResolver;
  _MorphDescendantFlightRecord? _flightRecord;
  int? _flightRecordsRevision;
  bool _inFlight = false;
  bool _insideNestedMorph = false;

  void _detachEndpoint() {
    _endpoint?._unregisterDescendant(_handle);
    _endpoint = null;
  }

  void _resolveFlightRecord() {
    _flightRecord = null;
    final resolver = _flightResolver;
    if (resolver == null) return;
    _flightRecordsRevision = resolver.recordsRevision;
    _flightRecord = resolver.resolve(this);
  }

  void _attachFlightResolver(_MorphDescendantFlightResolver? resolver) {
    if (identical(resolver, _flightResolver)) return;
    _flightResolver?.removeListener(_handleFlightEndpointChanged);
    _flightResolver?.release(this);
    _flightRecord = null;
    _flightResolver = resolver;
    resolver?.addListener(_handleFlightEndpointChanged);
    _resolveFlightRecord();
  }

  void _handleFlightEndpointChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _synchronizeEndpoint() {
    if (_inFlight || widget.flightBehavior.isLive) {
      _detachEndpoint();
      return;
    }
    final endpoint = _MorphEndpointScope.maybeOf(context);
    if (identical(endpoint, _endpoint)) return;
    _detachEndpoint();
    _endpoint = endpoint;
    endpoint?._registerDescendant(_handle);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final flightScope = _MorphFlightScope.scopeOf(context);
    _inFlight = flightScope != null;
    final registration = _MorphDescendantFlightScope.maybeOf(context);
    _insideNestedMorph =
        _inFlight &&
        registration != null &&
        identical(registration.flightScope, flightScope) &&
        registration.resolver == null;
    final flightResolver = registration != null && identical(registration.flightScope, flightScope)
        ? registration.resolver
        : null;
    _attachFlightResolver(flightResolver);
    _synchronizeEndpoint();
  }

  @override
  void didUpdateWidget(MorphDescendant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flightBehavior != widget.flightBehavior) {
      _handle.markSnapshotDirty();
    }
    if (_flightResolver != null &&
        (_flightResolver!.recordsRevision != _flightRecordsRevision || !identical(oldWidget, widget))) {
      _resolveFlightRecord();
    }
    if (oldWidget.flightBehavior != widget.flightBehavior) {
      _synchronizeEndpoint();
    }
  }

  @override
  void deactivate() {
    _flightResolver?.release(this);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _resolveFlightRecord();
  }

  @override
  void dispose() {
    _detachEndpoint();
    _flightResolver?.removeListener(_handleFlightEndpointChanged);
    _flightResolver?.release(this);
    _handle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flightBehavior.isLive || _insideNestedMorph) return widget.child;
    if (_inFlight) {
      assert(
        _flightResolver != null,
        'A Morph flight must display snapshot and hidden descendants '
        'through the widget returned by endpoint.descendantWidget(...). '
        'Register their subtree in MorphFlightDelegate.properties and use the returned widget in the flight.',
      );
      if (_flightResolver?.recordsRevision != _flightRecordsRevision) {
        _resolveFlightRecord();
      }
      final record = _flightRecord;
      if (record == null) return const SizedBox.shrink();
      return SizedBox.fromSize(
        size: record.size,
        child: widget.flightBehavior.usesSnapshot ? record.snapshot?.build() : null,
      );
    }
    return _MorphDescendantBoundary(
      onRenderObjectReady: _handle.attachRenderObject,
      child: widget.child,
    );
  }
}
