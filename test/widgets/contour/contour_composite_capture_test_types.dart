part of 'contour_composite_capture_test_adapter.dart';

/// Describes one source admitted by a controlled capture.
typedef ContourCompositeCaptureTestSubmission = ({
  int id,
  ui.Picture source,
  ui.Picture picture,
  int width,
  int height,
  double outputRatio,
});
