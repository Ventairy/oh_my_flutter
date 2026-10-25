import 'dart:ui';

/// Exercises a caller-defined offset type that can retain additional state.
class ContourShadowCustomOffset extends Offset {
  /// Creates a custom offset with an ordinary visible translation.
  const new() : super(0, 2);
}
