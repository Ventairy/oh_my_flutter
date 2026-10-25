import 'dart:ui' as ui;

import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_capture.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_result.dart';

/// Counts source tiles submitted to the actual standard-engine backend.
class ContourCompositeCountingCapture implements ContourCompositeCapture {
  /// Wraps a normal backend without changing source pictures or results.
  const new(this.delegate, this.onCapture);

  /// The actual source backend used by the test.
  final ContourCompositeCapture delegate;

  /// Records each captured tile's dimensions.
  final void Function(int width, int height) onCapture;

  @override
  bool get available => delegate.available;

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
  }) {
    onCapture(width, height);
    return delegate.capturePicture(
      source,
      width: width,
      height: height,
      sourceRatio: sourceRatio,
      outputRatio: outputRatio,
      amountOutputPx: amountOutputPx,
      contourArgb: contourArgb,
      shadowArgb: shadowArgb,
      shadowSigmaOutputPx: shadowSigmaOutputPx,
      shadowDxOutputPx: shadowDxOutputPx,
      shadowDyOutputPx: shadowDyOutputPx,
      cancelled: cancelled,
    );
  }
}
