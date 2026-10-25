import 'dart:ui' as ui;

import 'package:meta/meta.dart';

import 'contour_composite_capture.dart';
import 'contour_composite_result.dart';

/// Keeps unsupported platforms on their existing contour renderer.
@internal
final class ContourCompositeSource implements ContourCompositeCapture {
  new _();

  /// Shares the unsupported capability without allocating native resources.
  static final _shared = ContourCompositeSource._();

  /// Installs an isolated public-API-only source in focused tests.
  @visibleForTesting
  static ContourCompositeCapture? testOverride;

  /// Returns the normal unsupported backend unless a test overrides it.
  static ContourCompositeCapture get shared => testOverride ?? _shared;

  /// Whether standard native decoration capture is available.
  @override
  bool get available => false;

  /// Declines sources without retaining their picture.
  @override
  Future<ContourCompositeResult?> capturePicture(
    ui.Picture source, {
    required int width,
    required int height,
    required double sourceRatio,
    required double outputRatio,
    required double amountOutputPx,
    required int contourArgb,
    required int shadowArgb,
    required double shadowSigmaOutputPx,
    required double shadowDxOutputPx,
    required double shadowDyOutputPx,
    required Future<void> cancelled,
  }) async => null;
}
