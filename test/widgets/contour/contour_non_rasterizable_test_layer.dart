import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Marks otherwise ordinary painted content as unavailable for image capture.
class ContourNonRasterizableTestLayer extends Layer {
  @override
  bool supportsRasterization() => false;

  @override
  void addToScene(ui.SceneBuilder builder) {}
}
