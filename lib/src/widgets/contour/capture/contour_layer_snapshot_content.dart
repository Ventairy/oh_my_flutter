import 'dart:ui' as ui;

import 'package:meta/meta.dart';

/// Supplies the recorded content of a layer owned by Contour.
///
/// This internal capability excludes unrelated layer subclasses. Its values
/// describe visible picture commands independently from scene bookkeeping.
@internal
abstract interface class ContourLayerSnapshotContent {
  /// Whether the recorded content still matches its current source.
  bool get snapshotIsCurrent;

  /// The translation applied to both this layer's picture and children.
  ui.Offset get snapshotChildOffset;

  /// The current borrowed decoration, or null for an offset-only wrapper.
  ui.Picture? get snapshotPicture;

  /// An additional translation applied only to the recorded picture.
  ui.Offset get snapshotPictureOffset;
}
