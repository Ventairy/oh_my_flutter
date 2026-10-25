import 'dart:typed_data';

/// Supplies closed cubic outlines without relying on font or platform assets.
class ContourGeometryTestData {
  /// A rectangle made of linear cubics in captured pixel coordinates.
  static List<Float64List> rectangle({double left = 0, double top = 0, double scale = 1}) => [
    Float64List.fromList([
      left,
      top,
      left + 4 * scale,
      top,
      left + 8 * scale,
      top,
      left + 12 * scale,
      top,
      left + 12 * scale,
      top + 4 * scale,
      left + 12 * scale,
      top + 8 * scale,
      left + 12 * scale,
      top + 12 * scale,
      left + 8 * scale,
      top + 12 * scale,
      left + 4 * scale,
      top + 12 * scale,
      left,
      top + 12 * scale,
      left,
      top + 8 * scale,
      left,
      top + 4 * scale,
      left,
      top,
    ]),
  ];
}
