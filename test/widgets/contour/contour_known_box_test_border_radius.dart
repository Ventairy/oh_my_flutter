import 'package:flutter/painting.dart';

/// Exercises rejection of consumer-defined corner geometry.
class ContourKnownBoxTestBorderRadius extends BorderRadius {
  /// Creates an otherwise ordinary rounded corner shape.
  const new() : super.all(const Radius.circular(5));
}
