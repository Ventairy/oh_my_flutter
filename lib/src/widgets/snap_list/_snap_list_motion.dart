part of 'snap_list.dart';

class _SnapListMotion extends ChangeNotifier {
  new({
    required this.commitThreshold,
    required this.duration,
    required this.reverseDuration,
    required this.curve,
    required this.reverseCurve,
    required this.reducedMotion,
  });

  static const _minFlingVelocity = 400.0;

  double commitThreshold;
  Duration duration;
  Duration reverseDuration;
  Curve curve;
  Curve reverseCurve;
  bool reducedMotion;
  _SnapListPosition? scroll;
  int count = 0;
  int? index;
  int? target;
  double stride = 1;
  double revealExtent = 0;
  bool moving = false;
  bool dragging = false;
  bool trailingCommitted = false;
  bool _trailingChanged = false;
  bool _preserveOffset = false;
  int? _appendTarget;
  int _anchor = 0;
  int _generation = 0;
  Completer<bool>? _result;
  Timer? _wheelTimer;
  bool _wheelActive = false;
  double? _lastPosition;
  bool _tickerEnabled = true;
  ({int generation, double destination})? _activeSettle;

  double get pixels => scroll?.hasPixels ?? false ? scroll!.pixels : 0;
  double? get itemPosition => count == 0 ? null : pixels / stride;
  double get lastAnchor => math.max(0, count - 1) * stride;
  double get maxExtent => count == 0 ? 0 : math.max(lastAnchor + revealExtent, _preserveOffset ? pixels : 0);
  double get displayPixels =>
      reducedMotion ? (trailingCommitted ? lastAnchor + revealExtent : (index ?? 0) * stride) : pixels;
  double get dragMin => math.max(0, (_anchor - 1) * stride);
  double get dragMax => _anchor == count - 1 ? maxExtent : math.min(maxExtent, (_anchor + 1) * stride);

  void configure({
    required int itemCount,
    required double itemStride,
    int? retainIndex,
  }) {
    if (itemCount > count && trailingCommitted) {
      _appendTarget ??= count;
      _preserveOffset = true;
    }
    count = itemCount;
    stride = itemStride;
    index = count == 0 ? null : (retainIndex ?? index ?? 0).clamp(0, count - 1);
  }

  void changed() {
    final value = itemPosition;
    if (value == _lastPosition) return;
    _lastPosition = value;
    notifyListeners();
  }

  void _complete(bool success) {
    _result?.complete(success);
    _result = null;
  }

  void interrupt() {
    _wheelTimer?.cancel();
    _wheelTimer = null;
    _wheelActive = false;
    _generation++;
    _complete(false);
    trailingCommitted = false;
    _appendTarget = null;
    _preserveOffset = false;
    target = null;
    _activeSettle = null;
    scroll?.goIdle();
  }

  void updateTickerMode({required bool enabled}) {
    _tickerEnabled = enabled;
    if (enabled) return;
    final activeSettle = _activeSettle;
    if (activeSettle == null || activeSettle.generation != _generation) return;
    scroll?.jumpTo(activeSettle.destination);
  }

  void beginDrag() {
    interrupt();
    _anchor = (itemPosition ?? 0).round().clamp(0, math.max(0, count - 1));
    dragging = true;
  }

  void userMoved() {
    if (!moving) {
      moving = true;
      notifyListeners();
    }
  }

  void cancelDrag() {
    dragging = false;
    unawaited(_settle(_anchor * stride, cancel: true));
  }

  void release(double velocity) {
    if (!dragging) return;
    dragging = false;
    final delta = pixels - _anchor * stride;
    final direction = velocity.abs() >= _minFlingVelocity ? velocity.sign : delta.sign;
    final commit = delta.abs() >= stride * commitThreshold || velocity.abs() >= _minFlingVelocity;
    final destination = commit ? _anchor + direction.toInt() : _anchor;
    if (_anchor == count - 1 && delta > 0 && revealExtent > 0) {
      final reveal = pixels - lastAnchor;
      final commitReveal = velocity.abs() >= _minFlingVelocity
          ? velocity > 0
          : reveal >= revealExtent * commitThreshold;
      trailingCommitted = commitReveal;
      unawaited(_settle(commitReveal ? maxExtent : lastAnchor, cancel: !commitReveal));
      return;
    }
    unawaited(_settle(destination.clamp(0, math.max(0, count - 1)) * stride, cancel: !commit, reverse: direction < 0));
  }

  Future<bool> navigate(int direction) {
    if (dragging || count == 0 || scroll == null || !scroll!.hasContentDimensions) return Future<bool>.value(false);
    final destination = (index ?? 0) + (trailingCommitted && direction < 0 ? 0 : direction);
    if (destination < 0 || destination > count || (destination == count && revealExtent == 0)) {
      return Future<bool>.value(false);
    }
    interrupt();
    final result = Completer<bool>();
    _result = result;
    trailingCommitted = destination == count;
    unawaited(_settle(destination == count ? maxExtent : destination * stride, reverse: direction < 0));
    return result.future;
  }

  Future<void> _settle(double destination, {bool cancel = false, bool reverse = false}) async {
    final position = scroll;
    if (position == null) return;
    final generation = ++_generation;
    _activeSettle = (generation: generation, destination: destination);
    target = destination <= lastAnchor && count > 0 ? (destination / stride).round() : null;
    moving = (pixels - destination).abs() > precisionErrorTolerance;
    notifyListeners();
    final useReverse = cancel || reverse;
    final duration = useReverse ? reverseDuration : this.duration;
    if (reducedMotion || !_tickerEnabled || duration == Duration.zero || !moving) {
      position.jumpTo(destination);
    } else {
      await position.animateTo(destination, duration: duration, curve: useReverse ? reverseCurve : curve);
    }
    if (generation != _generation) return;
    _activeSettle = null;
    moving = false;
    if (!trailingCommitted && target != null) index = target;
    final reachedItem = target != null;
    target = null;
    _preserveOffset = false;
    _complete(!cancel && reachedItem);
    notifyListeners();
  }

  void measureTrailing(double extent) {
    if (extent == revealExtent) return;
    if (trailingCommitted) _preserveOffset = true;
    revealExtent = extent;
    _trailingChanged = true;
  }

  void resolveTrailing() {
    final appended = _appendTarget;
    _appendTarget = null;
    if (appended != null && trailingCommitted) {
      trailingCommitted = false;
      _trailingChanged = false;
      unawaited(_settle(appended * stride));
    } else if (_trailingChanged) {
      _trailingChanged = false;
      if (trailingCommitted) {
        trailingCommitted = revealExtent > 0;
        unawaited(_settle(lastAnchor + revealExtent, cancel: !trailingCommitted));
      }
    }
  }

  void reset() {
    interrupt();
    dragging = false;
    moving = false;
    scroll?.correctPixels((index ?? 0) * stride);
  }

  void wheel(double delta) {
    if (delta == 0 || count == 0) return;
    if (!_wheelActive) beginDrag();
    _wheelActive = true;
    _wheelTimer?.cancel();
    final destination = (pixels + delta).clamp(dragMin, dragMax);
    if (destination != pixels) {
      userMoved();
      scroll!.movePixels(destination);
    }
    _wheelTimer = Timer(const Duration(milliseconds: 120), () {
      _wheelActive = false;
      release(0);
    });
  }

  @override
  void dispose() {
    interrupt();
    scroll = null;
    super.dispose();
  }
}
