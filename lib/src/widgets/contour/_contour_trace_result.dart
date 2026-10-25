part of 'contour.dart';

class _ContourTraceResult {
  const new success(this.contours) : capacityExceeded = false;

  const new capacity() : contours = const [], capacityExceeded = true;

  final List<Float64List> contours;
  final bool capacityExceeded;
}
