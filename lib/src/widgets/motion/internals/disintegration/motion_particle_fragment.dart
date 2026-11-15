part of '../../motion.dart';

class _MotionParticleFragment {
  new({
    required this.bounds,
    required this.operations,
    required int budget,
    required this.firstParticle,
    required this.sourceRegion,
  }) {
    expectedCount = operations._operationCount;
    for (var index = 0; index < expectedCount; index++) {
      final operation = operations._operations![index];
      if (operation.kind == .disintegrate) sizes[index] = operation.particleSize;
    }
    var stageBudget = budget;
    while (true) {
      stages.clear();
      final horizontal = <double>{bounds.left, bounds.right};
      final vertical = <double>{bounds.top, bounds.bottom};
      for (final entry in sizes.entries) {
        final stage = _MotionParticleStage(bounds: bounds, particleSize: entry.value, budget: stageBudget);
        stages[entry.key] = stage;
        for (var column = 1; column < stage.columns; column++) {
          horizontal.add(bounds.left + column * bounds.width / stage.columns);
        }
        for (var row = 1; row < stage.rows; row++) {
          vertical.add(bounds.top + row * bounds.height / stage.rows);
        }
      }
      _horizontalEdges = horizontal.toList()..sort();
      _verticalEdges = vertical.toList()..sort();
      columns = _horizontalEdges.length - 1;
      rows = _verticalEdges.length - 1;
      if (count <= budget) break;
      stageBudget = math.max(1, (stageBudget * budget / count * 0.95).floor());
    }
  }

  final Rect bounds;
  final Rect sourceRegion;
  final MotionEffectTransform operations;
  final int firstParticle;
  late final Offset _pivot = bounds.center;
  final Map<int, _MotionParticleStage> stages = {};
  final Map<int, double> sizes = {};
  late int columns;
  late int rows;
  late List<double> _horizontalEdges;
  late List<double> _verticalEdges;
  late final int expectedCount;
  double _x = 0;
  double _y = 0;
  double _scaleCosine = 1;
  double _scaleSine = 0;
  double _opacity = 1;

  int get count => columns * rows;

  void validate() {
    assert(expectedCount == operations._operationCount, 'Rendering operation count must remain constant.');
    assert(
      sizes.entries.every((entry) => operations._operations![entry.key].particleSize == entry.value),
      'particleSize must remain constant throughout playback.',
    );
  }

  void prepareAnchors() {
    for (final entry in stages.entries) {
      final stage = entry.value..updateFrame(operations._operations![entry.key]);
      for (var particle = 0; particle < stage.count; particle++) {
        _evaluate(stage.centerX[particle], stage.centerY[particle], entry.key);
        stage.anchorX[particle] = _x;
        stage.anchorY[particle] = _y;
      }
    }
  }

  void _evaluate(double sourceX, double sourceY, int end) {
    var x = sourceX;
    var y = sourceY;
    var scaleCosine = 1.0;
    var scaleSine = 0.0;
    var opacity = 1.0;
    final pivotX = _pivot.dx;
    final pivotY = _pivot.dy;
    for (var index = 0; index < end; index++) {
      final operation = operations._operations![index];
      switch (operation.kind) {
        case .transform:
          final cosine = operation.cosine * operation.scale;
          final sine = operation.sine * operation.scale;
          final previousX = x - pivotX;
          final previousY = y - pivotY;
          x = cosine * previousX - sine * previousY + pivotX + operation.x;
          y = sine * previousX + cosine * previousY + pivotY + operation.y;
          final previousScaleCosine = scaleCosine;
          scaleCosine = cosine * scaleCosine - sine * scaleSine;
          scaleSine = sine * previousScaleCosine + cosine * scaleSine;
          opacity *= operation.opacity.clamp(0.0, 1.0);
        case .disintegrate:
          final stage = stages[index]!;
          final group = stage.groupAt(sourceX, sourceY);
          final anchorX = stage.anchorX[group];
          final anchorY = stage.anchorY[group];
          x = anchorX + (x - anchorX) * stage.scale[group] + stage.offsetX[group];
          y = anchorY + (y - anchorY) * stage.scale[group] + stage.offsetY[group];
          scaleCosine *= stage.scale[group];
          scaleSine *= stage.scale[group];
          opacity *= stage.opacity[group];
      }
    }
    _x = x;
    _y = y;
    _scaleCosine = scaleCosine;
    _scaleSine = scaleSine;
    _opacity = opacity;
  }

  void writeSourceRects(Float32List rects) {
    for (var index = 0; index < count; index++) {
      final column = index % columns;
      final row = index ~/ columns;
      final offset = (firstParticle + index) * 4;
      rects[offset] = sourceRegion.left + (_horizontalEdges[column] - bounds.left) / bounds.width * sourceRegion.width;
      rects[offset + 1] = sourceRegion.top + (_verticalEdges[row] - bounds.top) / bounds.height * sourceRegion.height;
      rects[offset + 2] =
          sourceRegion.left + (_horizontalEdges[column + 1] - bounds.left) / bounds.width * sourceRegion.width;
      rects[offset + 3] =
          sourceRegion.top + (_verticalEdges[row + 1] - bounds.top) / bounds.height * sourceRegion.height;
    }
  }

  void write(Float32List transforms, Int32List colors) {
    validate();
    prepareAnchors();
    for (var index = 0; index < count; index++) {
      final column = index % columns;
      final row = index ~/ columns;
      final width = _horizontalEdges[column + 1] - _horizontalEdges[column];
      final height = _verticalEdges[row + 1] - _verticalEdges[row];
      final x = _horizontalEdges[column] + width / 2;
      final y = _verticalEdges[row] + height / 2;
      _evaluate(x, y, operations._operationCount);
      final offset = (firstParticle + index) * 4;
      transforms[offset] = _scaleCosine * bounds.width / sourceRegion.width;
      transforms[offset + 1] = _scaleSine * bounds.width / sourceRegion.width;
      transforms[offset + 2] = _x - _scaleCosine * width / 2 + _scaleSine * height / 2;
      transforms[offset + 3] = _y - _scaleSine * width / 2 - _scaleCosine * height / 2;
      colors[firstParticle + index] = (_opacity.clamp(0.0, 1.0) * 255).round() << 24;
    }
  }
}
