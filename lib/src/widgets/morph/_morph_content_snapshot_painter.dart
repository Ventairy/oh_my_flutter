part of 'morph.dart';

final class _MorphContentSnapshotPainter extends CustomPainter {
  _MorphContentSnapshotPainter({
    required this.atlas,
    required this.sourceRect,
  });

  final _MorphSnapshotAtlas atlas;
  final Rect sourceRect;
  final Paint _paint = Paint()..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      atlas.image,
      sourceRect,
      Offset.zero & size,
      _paint,
    );
  }

  @override
  bool shouldRepaint(_MorphContentSnapshotPainter oldDelegate) {
    return !identical(atlas, oldDelegate.atlas) || sourceRect != oldDelegate.sourceRect;
  }
}
