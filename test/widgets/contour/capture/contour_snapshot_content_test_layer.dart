import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:oh_my_flutter/src/widgets/contour/capture/contour_layer_snapshot_content.dart';

/// Supplies mutable owned-layer values without changing scene bookkeeping.
class ContourSnapshotContentTestLayer extends ContainerLayer implements ContourLayerSnapshotContent {
  @override
  bool snapshotIsCurrent = true;

  @override
  ui.Offset snapshotChildOffset = ui.Offset.zero;

  @override
  ui.Picture? snapshotPicture;

  @override
  ui.Offset snapshotPictureOffset = ui.Offset.zero;
}
