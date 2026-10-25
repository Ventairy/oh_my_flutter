import 'package:flutter/painting.dart';

/// Exercises rejection of consumer-defined box painting behavior.
class ContourKnownBoxTestDecoration extends BoxDecoration {
  /// Creates an otherwise ordinary opaque decoration.
  const new() : super(color: const Color(0xffff0000));
}
