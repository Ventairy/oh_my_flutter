import 'dart:ui' as ui;

/// Tracks rasterizer-owned pictures and images without masking leaked resources.
class ContourShadowAtlasRasterizerTestHarness {
  /// Creates an owned source and begins observing subsequently created resources.
  new() : source = createPicture() {
    _pictures.add(source);
    _previousPictureCreated = ui.Picture.onCreate;
    _previousPictureDisposed = ui.Picture.onDispose;
    _previousImageCreated = ui.Image.onCreate;
    _previousImageDisposed = ui.Image.onDispose;
    ui.Picture.onCreate = (picture) {
      _pictures.add(picture);
      _previousPictureCreated?.call(picture);
    };
    ui.Picture.onDispose = (picture) {
      _disposedPictures.add(picture);
      _previousPictureDisposed?.call(picture);
    };
    ui.Image.onCreate = (image) {
      _images.add(image);
      _previousImageCreated?.call(image);
    };
    ui.Image.onDispose = (image) {
      _disposedImages.add(image);
      _previousImageDisposed?.call(image);
    };
  }

  /// The supplied picture whose ownership transfers to the rasterizer.
  final ui.Picture source;
  final _pictures = Set<ui.Picture>.identity();
  final _disposedPictures = Set<ui.Picture>.identity();
  final _images = Set<ui.Image>.identity();
  final _disposedImages = Set<ui.Image>.identity();
  void Function(ui.Picture)? _previousPictureCreated;
  void Function(ui.Picture)? _previousPictureDisposed;
  void Function(ui.Image)? _previousImageCreated;
  void Function(ui.Image)? _previousImageDisposed;

  /// Whether every supplied or observed picture has been disposed.
  bool get allPicturesDisposed => _pictures.every(_disposedPictures.contains);

  /// Whether every image created during the operation has been disposed.
  bool get allImagesDisposed => _images.every(_disposedImages.contains);

  /// Whether every image other than the caller-owned result has been disposed.
  bool intermediatesDisposed(ui.Image result) =>
      _images.where((image) => !identical(image, result)).every(_disposedImages.contains);

  /// Whether the observed result has been disposed by its owner.
  bool resultDisposed(ui.Image result) => _disposedImages.contains(result);

  /// Supplies colored translucent shadows with curved and closed inner edges.
  static ui.Picture createPicture() {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(3);
    final path = ui.Path()
      ..fillType = ui.PathFillType.evenOdd
      ..addOval(const ui.Rect.fromLTWH(10, 6, 12, 12))
      ..addOval(const ui.Rect.fromLTWH(13, 9, 6, 6));
    final fill = ui.Paint()..color = const ui.Color(0xffffffff);
    final stroke = ui.Paint()
      ..color = const ui.Color(0xffffffff)
      ..style = ui.PaintingStyle.stroke
      ..strokeJoin = ui.StrokeJoin.round
      ..strokeWidth = 2.2;
    for (final shadow in const [
      (ui.Color.from(alpha: .1, red: 1, green: 0, blue: 0), ui.Offset(0, 1), 1.5),
      (ui.Color.from(alpha: .1, red: 0, green: 0, blue: 1), ui.Offset(1, 2), 2.5),
    ]) {
      canvas
        ..save()
        ..translate(shadow.$2.dx, shadow.$2.dy)
        ..saveLayer(
          const ui.Rect.fromLTWH(0, 0, 32, 24),
          ui.Paint()
            ..colorFilter = ui.ColorFilter.mode(shadow.$1, ui.BlendMode.srcIn)
            ..imageFilter = ui.ImageFilter.blur(sigmaX: shadow.$3, sigmaY: shadow.$3),
        )
        ..drawPath(path, fill)
        ..drawPath(path, stroke)
        ..restore()
        ..restore();
    }
    return recorder.endRecording();
  }

  /// Restores resource callbacks and cleans leaks only after assertions observed them.
  void dispose() {
    // Cleanup must still pass through these callbacks so existing test-level
    // resource observers see leaked objects being released.
    try {
      for (final picture in _pictures.where((picture) => !_disposedPictures.contains(picture)).toList()) {
        picture.dispose();
      }
      for (final image in _images.where((image) => !_disposedImages.contains(image)).toList()) {
        image.dispose();
      }
    } finally {
      ui.Picture.onCreate = _previousPictureCreated;
      ui.Picture.onDispose = _previousPictureDisposed;
      ui.Image.onCreate = _previousImageCreated;
      ui.Image.onDispose = _previousImageDisposed;
    }
  }
}
