part of 'morph.dart';

final class _MorphContentSnapshotPainter extends CustomPainter {
  _MorphContentSnapshotPainter({
    required this.tiles,
  });

  final List<_MorphContentSnapshotTile> tiles;
  final Paint _paint = Paint()..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    for (final tile in tiles) {
      canvas.drawImageRect(
        tile.atlas.image,
        tile.sourceRect,
        tile.destinationRect,
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MorphContentSnapshotPainter oldDelegate) {
    return !identical(tiles, oldDelegate.tiles);
  }
}
