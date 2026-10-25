part of 'contour.dart';

class _ContourShadowCache {
  new(this.onReady);

  // A shadow contains no sharp source detail. Two samples per logical pixel
  // preserve soft edges without retaining a full device-density texture.
  static const int _maximumPixels = 256 * 1024;

  final VoidCallback onReady;
  final Paint _paint = Paint()..filterQuality = FilterQuality.low;
  Timer? _timer;
  int? _frameCallbackId;
  bool _framePending = false;
  Completer<void>? _fenceCancellation;
  _ContourImageResource? _resource;
  int _revision = 0;
  int _running = 0;
  int buildCount = 0;

  bool get ready => _resource?.image != null;
  bool get generating => _timer != null || _framePending || _running > 0;
  int get resourceId => _resource?.id ?? 0;

  void invalidate() {
    _revision++;
    _timer?.cancel();
    _timer = null;
    if (_frameCallbackId case final int id) SchedulerBinding.instance.cancelFrameCallbackWithId(id);
    _frameCallbackId = null;
    _framePending = false;
    final cancellation = _fenceCancellation;
    _fenceCancellation = null;
    if (cancellation != null && !cancellation.isCompleted) cancellation.complete();
    final resource = _resource;
    _resource = null;
    if (resource != null) _ContourImagePool.release(resource);
  }

  void schedule({
    required Object key,
    required Rect bounds,
    required double pixelRatio,
    required bool Function() isCurrentSource,
    required void Function(Canvas) paint,
  }) {
    invalidate();
    if (bounds.isEmpty || !bounds.isFinite) return;
    final ratio = math.min<double>(pixelRatio, 2);
    final width = (bounds.width * ratio).ceil();
    final height = (bounds.height * ratio).ceil();
    final pixels = width * height;
    if (pixels > _maximumPixels || width > 2048 || height > 2048) return;
    final revision = _revision;
    final existing = _ContourImagePool.retainExisting(key);
    if (existing != null) {
      _resource = existing;
      if (existing.image == null) unawaited(_waitFor(existing, revision));
      return;
    }
    final cancellation = Completer<void>();
    _fenceCancellation = cancellation;
    _timer = Timer(const Duration(milliseconds: 120), () {
      _timer = null;
      // A slow frame can outlast the debounce interval. Let its next build
      // cancel an obsolete style before recording another image.
      _framePending = true;
      _frameCallbackId = SchedulerBinding.instance.scheduleFrameCallback((_) {
        _frameCallbackId = null;
        if (_revision != revision) return;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          unawaited(
            _prepareImage(
              key: key,
              bounds: bounds,
              ratio: ratio,
              width: width,
              height: height,
              pixels: pixels,
              revision: revision,
              cancellation: cancellation,
              isCurrentSource: isCurrentSource,
              paint: paint,
            ),
          );
        });
      });
    });
  }

  Future<void> _prepareImage({
    required Object key,
    required Rect bounds,
    required double ratio,
    required int width,
    required int height,
    required int pixels,
    required int revision,
    required Completer<void> cancellation,
    required bool Function() isCurrentSource,
    required void Function(Canvas) paint,
  }) async {
    try {
      // Let every post-frame callback register its initial foreground work.
      await Future<void>.value();
      if (_revision != revision || cancellation.isCompleted) return;
      do {
        if (!await ContourInitialFrameFence.shared.wait(cancelled: cancellation.future)) return;
        if (_revision != revision || cancellation.isCompleted) return;
      } while (!ContourInitialFrameFence.shared.ready);
      if (!isCurrentSource()) return;
      _framePending = false;
      final claim = _ContourImagePool.obtain(
        key: key,
        bounds: bounds,
        ratio: ratio,
        width: width,
        height: height,
        pixels: pixels,
        paint: paint,
      );
      if (claim.resource case final _ContourImageResource resource) {
        _resource = resource;
        if (claim.owner) buildCount++;
        unawaited(_waitFor(resource, revision));
      }
    } finally {
      if (identical(_fenceCancellation, cancellation)) _fenceCancellation = null;
      if (_revision == revision) _framePending = false;
    }
  }

  Future<void> _waitFor(_ContourImageResource resource, int revision) async {
    _running++;
    try {
      final image = await resource.completion.future;
      if (_revision != revision || !identical(_resource, resource)) return;
      if (image == null) {
        _resource = null;
        _ContourImagePool.release(resource);
      } else {
        onReady();
      }
    } finally {
      _running--;
    }
  }

  void paint(Canvas canvas) {
    final resource = _resource!;
    final image = resource.image!;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      resource.bounds,
      _paint,
    );
  }
}
