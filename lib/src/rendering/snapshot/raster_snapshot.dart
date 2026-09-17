import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
part 'snapshot_atlas.dart';
part 'snapshot_tile.dart';
part '_snapshot_painter.dart';

@internal
final class RasterSnapshot {
  RasterSnapshot({
    required this.tiles,
    required this.size,
  }) {
    _painter = _MorphContentSnapshotPainter(
      tiles: tiles,
    );
  }

  factory RasterSnapshot.tiled({
    required OffsetLayer layer,
    required Size size,
    required double pixelRatio,
  }) {
    final physicalWidth = (size.width * pixelRatio).ceil();
    final physicalHeight = (size.height * pixelRatio).ceil();
    final tiles = <SnapshotTile>[];
    for (var physicalTop = 0; physicalTop < physicalHeight; physicalTop += maximumTilePhysicalExtent) {
      final tilePhysicalHeight = math.min(
        maximumTilePhysicalExtent,
        physicalHeight - physicalTop,
      );
      for (var physicalLeft = 0; physicalLeft < physicalWidth; physicalLeft += maximumTilePhysicalExtent) {
        final tilePhysicalWidth = math.min(
          maximumTilePhysicalExtent,
          physicalWidth - physicalLeft,
        );
        final logicalBounds = Rect.fromLTWH(
          physicalLeft / pixelRatio,
          physicalTop / pixelRatio,
          tilePhysicalWidth / pixelRatio,
          tilePhysicalHeight / pixelRatio,
        );
        final atlas = SnapshotAtlas(
          layer.toImageSync(logicalBounds, pixelRatio: pixelRatio),
        );
        tiles.add(
          SnapshotTile(
            atlas: atlas,
            sourceRect:
                Offset.zero &
                Size(
                  tilePhysicalWidth.toDouble(),
                  tilePhysicalHeight.toDouble(),
                ),
            destinationRect: logicalBounds,
          ),
        );
      }
    }
    return RasterSnapshot(tiles: tiles, size: size);
  }

  static const int maximumTilePhysicalExtent = 2048;
  static const int maximumCapturePhysicalPixels = 2048 * 2048;

  void paint(Canvas canvas, Offset offset) {
    canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    _painter.paint(canvas, size);
    canvas.restore();
  }

  final List<SnapshotTile> tiles;
  final Size size;
  late final _MorphContentSnapshotPainter _painter;
  late final Widget _widget = ClipRect(
    child: OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: size.width,
      maxWidth: size.width,
      minHeight: size.height,
      maxHeight: size.height,
      child: CustomPaint(painter: _painter),
    ),
  );

  Widget build() => _widget;

  void addAtlasesTo(Set<SnapshotAtlas> atlases) {
    for (final tile in tiles) {
      atlases.add(tile.atlas);
    }
  }

  void retain() {
    for (final tile in tiles) {
      tile.atlas.retain();
    }
  }

  void release() {
    for (final tile in tiles) {
      tile.atlas.release();
    }
  }
}
