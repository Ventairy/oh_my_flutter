part of 'morph.dart';

class _MorphEndpointHandle {
  _MorphEndpointHandle({
    required this.owner,
    required this.visibility,
    required this.overlay,
    required this.route,
    required this.parentEndpoint,
  }) {
    configurationChanged();
  }

  final _MorphState owner;
  final _MorphVisibilityHandle visibility;
  final OverlayState overlay;
  final ModalRoute<Object?>? route;
  _MorphEndpointHandle? parentEndpoint;

  late Object tag;
  late MorphFlightDelegate<Object?> delegate;
  late Duration duration;
  late Curve curve;
  late bool watch;
  VoidCallback? onStart;
  VoidCallback? onEnd;
  VoidCallback? onReceived;
  MorphEndpoint<Object?>? cachedEndpoint;
  int registrationOrder = 0;
  int retentionGeneration = 0;
  bool active = true;
  bool disposed = false;
  bool animationsDisabled = false;
  MorphEndpoint<Object?>? _sameFrameEndpoint;

  void configurationChanged() {
    final widget = owner.widget;
    tag = widget.tag;
    delegate = owner._resolvedFlightDelegate;
    duration = widget.duration ?? parentEndpoint?.duration ?? Morph._defaultDuration;
    curve = widget.curve ?? parentEndpoint?.curve ?? Morph._defaultCurve;
    watch = widget.watch;
    onStart = widget.onStart;
    onEnd = widget.onEnd;
    onReceived = widget.onReceived;
    if (owner.mounted) {
      animationsDisabled = MediaQuery.maybeDisableAnimationsOf(owner.context) ?? false;
    }
  }

  void _cacheCapture(MorphEndpoint<Object?> endpoint) {
    cachedEndpoint = endpoint;
    _sameFrameEndpoint = endpoint;
    scheduleMicrotask(() {
      if (identical(_sameFrameEndpoint, endpoint)) {
        _sameFrameEndpoint = null;
      }
    });
  }

  void captureDeparture() {
    final capturedEndpoint = owner._captureLastPainted();
    if (capturedEndpoint != null) {
      _cacheCapture(capturedEndpoint);
    }
  }

  MorphEndpoint<Object?>? capture({bool reuseSameFrame = false}) {
    final sameFrameEndpoint = _sameFrameEndpoint;
    if (reuseSameFrame && sameFrameEndpoint != null) {
      return sameFrameEndpoint;
    }
    if (active && owner.mounted) {
      final capturedEndpoint = owner._capture();
      if (capturedEndpoint != null) {
        _cacheCapture(capturedEndpoint);
      }
    }
    return cachedEndpoint;
  }
}
