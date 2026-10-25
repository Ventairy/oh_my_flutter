part of 'contour.dart';

class _ContourImagePool {
  static const int _maximumRetainedPixels = 4 * 1024 * 1024;
  static final _resources = <Object, _ContourImageResource>{};
  static int retainedPixels = 0;
  static int buildCount = 0;
  static int _nextId = 1;
  static int reuseCount = 0;
  static int get entries => _resources.length;
  static int pending = 0;

  static _ContourImageResource? retainExisting(Object key) {
    final resource = _resources[key];
    if (resource == null) return null;
    resource.references++;
    reuseCount++;
    return resource;
  }

  static ({_ContourImageResource? resource, bool owner}) obtain({
    required Object key,
    required Rect bounds,
    required double ratio,
    required int width,
    required int height,
    required int pixels,
    required void Function(Canvas) paint,
  }) => obtainImage(
    key: key,
    bounds: bounds,
    ratio: ratio,
    width: width,
    height: height,
    pixels: pixels,
    build: (resource) => _paint(resource, bounds, ratio, paint),
  );

  static ({_ContourImageResource? resource, bool owner}) obtainImage({
    required Object key,
    required Rect bounds,
    required double ratio,
    required int width,
    required int height,
    required int pixels,
    required Future<ui.Image?> Function(_ContourImageResource resource) build,
  }) {
    final existing = retainExisting(key);
    if (existing != null) {
      return (resource: existing, owner: false);
    }
    if (retainedPixels + pixels > _maximumRetainedPixels) {
      return (resource: null, owner: false);
    }
    final resource = _ContourImageResource(
      id: _nextId++,
      key: key,
      bounds: Rect.fromLTWH(bounds.left, bounds.top, width / ratio, height / ratio),
      width: width,
      height: height,
      pixels: pixels,
    );
    _resources[key] = resource;
    retainedPixels += pixels;
    buildCount++;
    pending++;
    _start(resource, build);
    return (resource: resource, owner: true);
  }

  static void release(_ContourImageResource resource) {
    assert(resource.references > 0, 'A contour image lease cannot be released twice.');
    resource.references--;
    if (resource.references != 0) return;
    // Waiting work has not used GPU scratch space and can retire immediately.
    // Remove it before another owner can inherit an already-canceled future.
    final canceled = resource.cancelQueued?.call() ?? 0;
    if (canceled > 0 || resource.completion.isCompleted) _remove(resource);
    // Active rasterization cannot be canceled. Its reservation survives until
    // completion, and an equivalent owner can still reuse that pending work.
  }

  static void _remove(_ContourImageResource resource) {
    if (resource.removed) return;
    resource.removed = true;
    if (identical(_resources[resource.key], resource)) _resources.remove(resource.key);
    retainedPixels -= resource.pixels;
    resource.image?.dispose();
    resource.image = null;
  }

  static Future<ui.Image> _paint(
    _ContourImageResource resource,
    Rect bounds,
    double ratio,
    void Function(Canvas) paint,
  ) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(ratio)
      ..translate(-bounds.left, -bounds.top);
    try {
      paint(canvas);
    } catch (_) {
      recorder.endRecording().dispose();
      rethrow;
    }
    return _rasterize(recorder.endRecording(), resource.width, resource.height);
  }

  static Future<ui.Image> _rasterize(ui.Picture picture, int width, int height) async {
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  static void _start(
    _ContourImageResource resource,
    Future<ui.Image?> Function(_ContourImageResource resource) build,
  ) {
    Future<ui.Image?> image;
    try {
      // Freeze the source synchronously. Only the returned future survives into
      // asynchronous completion; a renderer-owning factory is not retained.
      image = build(resource);
    } catch (error, stack) {
      image = Future<ui.Image?>.error(error, stack);
    }
    unawaited(_generate(resource, image));
  }

  static Future<void> _generate(
    _ContourImageResource resource,
    Future<ui.Image?> result,
  ) async {
    ui.Image? image;
    try {
      image = await result;
      if (resource.references > 0 && !resource.removed) {
        resource.image = image;
        image = null;
      }
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'Contour'));
    } finally {
      image?.dispose();
      resource.cancelQueued = null;
      if (resource.references == 0 || resource.image == null) _remove(resource);
      pending--;
      resource.completion.complete(resource.image);
    }
  }
}
