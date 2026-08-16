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
  const MorphDescendant({
    required this.flightBehavior,
    required this.child,
    super.key,
  });

  /// How [child] is represented while the nearest ancestor Morph transitions.
  ///
  /// Content without a MorphDescendant uses
  /// [MorphDescendantFlightBehavior.live]. A custom [MorphFlightDelegate]
  /// observes this behavior only when its flight result includes [child].
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
  bool? _flightShowsSource;
  bool _inFlight = false;

  void _detachEndpoint() {
    _endpoint?._unregisterDescendant(_handle);
    _endpoint = null;
  }

  void _releaseFlightRecord() {
    _flightResolver?.release(_flightRecord);
    _flightRecord = null;
  }

  void _resolveFlightRecord() {
    _releaseFlightRecord();
    final resolver = _flightResolver;
    if (resolver == null || widget.flightBehavior.isLive) return;
    _flightShowsSource = resolver.showsSource;
    _flightRecord = resolver.claim(
      key: widget.key,
      childType: widget.child.runtimeType,
      behavior: widget.flightBehavior,
    );
  }

  void _attachFlightResolver(_MorphDescendantFlightResolver? resolver) {
    if (identical(resolver, _flightResolver)) return;
    _flightResolver?.removeListener(_handleFlightEndpointChanged);
    _releaseFlightRecord();
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
    _inFlight = _MorphFlightScope.contains(context);
    final flightResolver = _MorphFlightScope.maybeOf(context);
    _attachFlightResolver(flightResolver);
    _synchronizeEndpoint();
  }

  @override
  void didUpdateWidget(MorphDescendant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_flightResolver != null &&
        (_flightResolver!.showsSource != _flightShowsSource ||
            oldWidget.flightBehavior != widget.flightBehavior ||
            oldWidget.child.runtimeType != widget.child.runtimeType)) {
      _resolveFlightRecord();
    }
    if (oldWidget.flightBehavior != widget.flightBehavior) {
      _synchronizeEndpoint();
    }
  }

  @override
  void dispose() {
    _detachEndpoint();
    _flightResolver?.removeListener(_handleFlightEndpointChanged);
    _releaseFlightRecord();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flightBehavior.isLive) return widget.child;
    if (_inFlight) {
      if (_flightResolver?.showsSource != _flightShowsSource) {
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
      onRenderObjectReady: (renderObject) => _handle.renderObject = renderObject,
      child: widget.child,
    );
  }
}
