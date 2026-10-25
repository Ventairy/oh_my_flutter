import 'dart:ui' as ui;

import 'package:meta/meta.dart';

import 'contour_composite_result.dart';

/// Captures an owned picture through standard rendering APIs.
@internal
abstract interface class ContourCompositeCapture {
  /// Whether this source can prepare the requested platform's decorations.
  bool get available;

  /// Retains the source synchronously and returns one independently owned result.
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
  });
}
