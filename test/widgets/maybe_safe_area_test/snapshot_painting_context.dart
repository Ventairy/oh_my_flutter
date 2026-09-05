import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

class SnapshotPaintingContext extends PaintingContext {
  SnapshotPaintingContext({required ContainerLayer layer, required Rect bounds}) : super(layer, bounds);

  static ui.Image capture(RenderBox box, Offset offset) {
    final layer = OffsetLayer();
    final bounds = Offset.zero & Size(box.size.width + offset.dx, box.size.height + offset.dy);
    final context = SnapshotPaintingContext(layer: layer, bounds: bounds);
    try {
      box.paint(context, offset);
      context.stopRecordingIfNeeded();
      return layer.toImageSync(bounds);
    } finally {
      box.markNeedsPaint();
      layer.dispose();
    }
  }
}
