import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Produces a downsampled shadow atlas and releases its temporary images.
class ContourShadowAtlasRasterizer {
  /// Creates the platform's atlas rasterizer.
  const new() : _createIntermediate = null;

  /// Replaces intermediate creation for isolated failure and ownership tests.
  @visibleForTesting
  new test({required ui.Image Function(ui.Picture picture, int width, int height) this._createIntermediate});

  final ui.Image Function(ui.Picture picture, int width, int height)? _createIntermediate;

  /// Rasterizes [picture] at [width] by [height], then downsamples its pixels.
  ///
  /// Takes ownership of [picture], including when rasterization fails. The
  /// caller owns the returned image, whose size is [outputWidth] by
  /// [outputHeight]. Temporary pictures and images are disposed before return.
  Future<ui.Image> rasterize({
    required ui.Picture picture,
    required int width,
    required int height,
    required int outputWidth,
    required int outputHeight,
  }) async {
    assert(width > 0 && height > 0, 'Intermediate dimensions must be positive.');
    assert(outputWidth > 0 && outputHeight > 0, 'Output dimensions must be positive.');
    ui.Picture? source = picture;
    ui.Picture? downsample;
    ui.Image? intermediate;
    ui.Image? result;
    try {
      final createIntermediate = _createIntermediate;
      if (createIntermediate != null) {
        intermediate = createIntermediate(picture, width, height);
      } else if (kIsWeb) {
        intermediate = await picture.toImage(width, height);
      } else {
        // The native handle is immediate; raster work still runs on the raster
        // queue. Skia can keep this large intermediate on the GPU for sampling.
        intermediate = picture.toImageSync(width, height);
      }
      source.dispose();
      source = null;
      final recorder = ui.PictureRecorder();
      try {
        ui.Canvas(recorder).drawImageRect(
          intermediate,
          ui.Rect.fromLTWH(0, 0, intermediate.width.toDouble(), intermediate.height.toDouble()),
          ui.Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
          ui.Paint()..filterQuality = ui.FilterQuality.low,
        );
      } finally {
        // An already-reported deferred error can interrupt the recorded draw.
        downsample = recorder.endRecording();
      }
      // Keep the final asynchronous capture: callers retain their source and
      // work reservations until native rasterization and validation finish.
      result = await downsample.toImage(outputWidth, outputHeight);
      if (!kIsWeb) _validate(intermediate);
      final image = result;
      result = null;
      return image;
    } finally {
      result?.dispose();
      downsample?.dispose();
      intermediate?.dispose();
      source?.dispose();
    }
  }

  void _validate(ui.Image image) {
    final recorder = ui.PictureRecorder();
    try {
      // A failed deferred intermediate can otherwise produce a blank final
      // image. Recording this draw checks its error after the native fence;
      // the discarded picture performs no additional GPU work or readback.
      ui.Canvas(recorder).drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        const ui.Rect.fromLTWH(0, 0, 1, 1),
        ui.Paint(),
      );
    } finally {
      recorder.endRecording().dispose();
    }
  }
}
