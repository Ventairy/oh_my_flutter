import 'package:flutter/painting.dart';

/// Exercises a color whose paragraph serialization differs from its channels.
class ContourNativeCustomColor extends Color {
  const new() : super(0xFFFFFFFF);

  @override
  int get value => 0x00FFFFFF;
}
