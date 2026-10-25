import 'dart:ui' as ui;

/// Owns one unpublished decoration capture response.
class ContourCompositeResult {
  /// Owns the prepared decoration until its receiver retires it.
  const new({
    required this.picture,
    required this.boundsPx,
    this.sourceTouchesBoundary = false,
  });

  /// The prepared decoration; the original child is painted independently.
  final ui.Picture picture;

  /// Painted bounds in physical source coordinates.
  final ui.Rect boundsPx;

  /// Whether visible source pixels were clipped by the capture grid.
  final bool sourceTouchesBoundary;

  /// Releases the owned picture after its last renderer reference is retired.
  void dispose() => picture.dispose();
}
