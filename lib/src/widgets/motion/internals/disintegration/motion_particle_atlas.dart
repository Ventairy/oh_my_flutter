part of '../../motion.dart';

/// Packs intact and rounded versions of each source cell into one atlas so
/// attached and detached particles can share the same draw call.
class _MotionParticleAtlas {
  new(ui.Image source, Iterable<_MotionParticleFragment> fragments) : roundedOffset = source.height.toDouble() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    canvas
      ..drawImage(source, Offset.zero, paint)
      ..translate(0, roundedOffset);
    final mask = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1;
    final grids = <(Rect, int, int)>{};
    for (final fragment in fragments) {
      final region = fragment.sourceRegion;
      final columns = fragment.columns;
      final rows = fragment.rows;
      if (columns == 0 || rows == 0 || !grids.add((region, columns, rows))) continue;
      final centers = Float32List(rows * columns * 2);
      var index = 0;
      for (var row = 0; row < rows; row++) {
        for (var column = 0; column < columns; column++) {
          centers[index++] = column + 0.5;
          centers[index++] = row + 0.5;
        }
      }
      canvas
        ..save()
        ..translate(region.left, region.top)
        ..scale(region.width / columns, region.height / rows)
        ..drawRawPoints(ui.PointMode.points, centers, mask)
        ..restore();
    }
    canvas.drawImage(source, Offset.zero, paint..blendMode = BlendMode.srcIn);
    final picture = recorder.endRecording();
    try {
      image = picture.toImageSync(source.width, source.height * 2);
    } finally {
      picture.dispose();
    }
  }

  final double roundedOffset;
  late final ui.Image image;

  void selectCells(
    _MotionParticleFragment fragment,
    Float32List transforms,
    Float32List rects, {
    required int count,
    required int end,
  }) {
    var intactScale = fragment.bounds.width / fragment.sourceRegion.width;
    for (var index = fragment.firstOperation; index < end; index++) {
      final operation = fragment.operations._operations![index];
      if (operation.kind == .transform) intactScale *= operation.scale;
    }
    // Let neighboring cells separate slightly before cutting their corners.
    final threshold = intactScale * intactScale * 0.90;
    final stop = (fragment.firstParticle + count) * 4;
    for (var i = fragment.firstParticle * 4; i < stop; i += 4) {
      final a = transforms[i];
      final b = transforms[i + 1];
      final rounded = a * a + b * b < threshold;
      if (rounded == (rects[i + 1] >= roundedOffset)) continue;
      final shift = rounded ? roundedOffset : -roundedOffset;
      rects[i + 1] += shift;
      rects[i + 3] += shift;
    }
  }
}
