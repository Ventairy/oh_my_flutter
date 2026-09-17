part of 'raster_snapshot.dart';

@internal
final class SnapshotTile {
  const SnapshotTile({
    required this.atlas,
    required this.sourceRect,
    required this.destinationRect,
  });

  final SnapshotAtlas atlas;
  final Rect sourceRect;
  final Rect destinationRect;
}
