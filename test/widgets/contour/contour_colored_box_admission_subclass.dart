import 'package:flutter/widgets.dart';

/// Exercises a subclass that inherits Flutter's ordinary colored-box renderer.
class ContourColoredBoxAdmissionSubclass extends ColoredBox {
  /// Creates an opaque box without changing the inherited renderer.
  const new({super.key}) : super(color: const Color(0xff2070d0));
}
