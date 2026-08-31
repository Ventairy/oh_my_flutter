part of 'morph.dart';

final class _MorphContentSnapshotTile {
  const _MorphContentSnapshotTile({
    required this.atlas,
    required this.sourceRect,
    required this.destinationRect,
  });

  final _MorphSnapshotAtlas atlas;
  final Rect sourceRect;
  final Rect destinationRect;
}
