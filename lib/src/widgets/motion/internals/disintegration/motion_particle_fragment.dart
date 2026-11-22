part of '../../motion.dart';

class _MotionParticleFragment {
  new({
    required this.bounds,
    required this.operations,
    required int budget,
    required this.firstParticle,
    required this.sourceRegion,
    this.firstOperation = 0,
    Offset? pivot,
  }) : _pivot = pivot ?? bounds.center {
    expectedCount = operations._operationCount;
    for (var index = firstOperation; index < expectedCount; index++) {
      final operation = operations._operations![index];
      if (operation.kind == .disintegrate) sizes[index] = operation.particleSize;
    }
    if (sizes.length == 1 && _prepareSingleStage(budget)) return;

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

  bool _prepareSingleStage(int budget) {
    final entry = sizes.entries.single;
    final stage = _MotionParticleStage(bounds: bounds, particleSize: entry.value, budget: budget);
    final horizontal = _orderedEdges(bounds.left, bounds.right, stage.columns);
    final vertical = _orderedEdges(bounds.top, bounds.bottom, stage.rows);
    if (horizontal == null || vertical == null) return false;

    stages[entry.key] = stage;
    _horizontalEdges = horizontal;
    _verticalEdges = vertical;
    columns = stage.columns;
    rows = stage.rows;
    return true;
  }

  static Float64List? _orderedEdges(double start, double end, int cells) {
    if (!(start < end)) return null;
    final edges = Float64List(cells + 1);
    final length = end - start;
    edges[0] = start;
    var previous = start;
    for (var cell = 1; cell < cells; cell++) {
      final edge = start + cell * length / cells;
      // Rounded or non-finite edges still need the general deduplication path.
      if (!(edge > previous && edge < end)) return null;
      edges[cell] = edge;
      previous = edge;
    }
    edges[cells] = end;
    return edges;
  }

  final Rect bounds;
  final Rect sourceRegion;
  final MotionEffectTransform operations;
  final int firstParticle;
  final int firstOperation;
  final Offset _pivot;
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

  void prepareAnchors(int end) {
    for (final entry in stages.entries) {
      if (entry.key >= end) break;
      final operation = operations._operations![entry.key];
      if (operation.progress == 0) continue;
      final stage = entry.value..updateFrame(operation);
      final columnCenters = stage.columnCenters;
      final rowCenters = stage.rowCenters;
      final anchorX = stage.anchorX;
      final anchorY = stage.anchorY;
      var particle = 0;
      for (final y in rowCenters) {
        for (final x in columnCenters) {
          _evaluate(x, y, entry.key);
          anchorX[particle] = _x;
          anchorY[particle++] = _y;
        }
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
    for (var index = firstOperation; index < end; index++) {
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
          if (operation.progress == 0) continue;
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

  late final Float32List _sourceHorizontalEdges = _sourceEdges(
    _horizontalEdges,
    bounds.left,
    bounds.width,
    sourceRegion.left,
    sourceRegion.width,
  );
  late final Float32List _sourceVerticalEdges = _sourceEdges(
    _verticalEdges,
    bounds.top,
    bounds.height,
    sourceRegion.top,
    sourceRegion.height,
  );

  static Float32List _sourceEdges(
    List<double> boundsEdges,
    double boundsOrigin,
    double boundsLength,
    double sourceOrigin,
    double sourceLength,
  ) {
    final edges = Float32List(boundsEdges.length);
    for (var index = 0; index < boundsEdges.length; index++) {
      edges[index] = sourceOrigin + (boundsEdges[index] - boundsOrigin) / boundsLength * sourceLength;
    }
    return edges;
  }

  void writeSourceRects(Float32List rects) {
    final horizontal = _sourceHorizontalEdges;
    final vertical = _sourceVerticalEdges;
    var offset = firstParticle * 4;
    for (var row = 0; row < rows; row++) {
      final top = vertical[row];
      final bottom = vertical[row + 1];
      for (var column = 0; column < columns; column++, offset += 4) {
        rects[offset] = horizontal[column];
        rects[offset + 1] = top;
        rects[offset + 2] = horizontal[column + 1];
        rects[offset + 3] = bottom;
      }
    }
  }

  void _writeFrozenStage(_MotionParticleStage stage, Float32List transforms, Int32List colors) {
    final values = operations._operations!;
    final operation = values[firstOperation];
    final suffix = values[firstOperation + 1];
    final suffixAlpha = suffix.opacity.clamp(0.0, 1.0);
    final suffixCosine = suffix.cosine * suffix.scale;
    final suffixSine = suffix.sine * suffix.scale;
    if (operation.progress >= 1 || suffixAlpha == 0 || suffix.scale == 0) {
      colors.fillRange(firstParticle, firstParticle + count, 0);
      return;
    }

    stage.updateFrame(operation, deferCurl: true);
    final width = _tileWidths;
    final height = _tileHeights;
    final centerX = _tileCentersX;
    final centerY = _tileCentersY;
    final stageX = stage.columnCenters;
    final stageY = stage.rowCenters;
    final spriteScale = bounds.width / sourceRegion.width;
    final pivotX = _pivot.dx;
    final pivotY = _pivot.dy;
    var particle = 0;
    for (var row = 0; row < rows; row++) {
      final tileY = centerY[row];
      final anchorY = stageY[row];
      final halfHeight = height[row] / 2;
      for (var column = 0; column < columns; column++, particle++) {
        final tileScale = stage.scale[particle];
        final anchorX = stageX[column];
        final x = anchorX + (centerX[column] - anchorX) * tileScale + stage.offsetX[particle] - pivotX;
        final y = anchorY + (tileY - anchorY) * tileScale + stage.offsetY[particle] - pivotY;
        final a = suffixCosine * tileScale;
        final b = suffixSine * tileScale;
        final halfWidth = width[column] / 2;
        final target = firstParticle + particle;
        final offset = target * 4;
        transforms[offset] = a * spriteScale;
        transforms[offset + 1] = b * spriteScale;
        transforms[offset + 2] =
            (suffixCosine * x - suffixSine * y + pivotX + suffix.x) - a * halfWidth + b * halfHeight;
        transforms[offset + 3] =
            (suffixSine * x + suffixCosine * y + pivotY + suffix.y) - b * halfWidth - a * halfHeight;
        colors[target] = (stage.opacity[particle] * suffixAlpha * 255).round() << 24;
      }
    }
  }

  int writeLiveFrozenStage(
    Float32List transforms,
    Float32List rects,
    Int32List colors, {
    int? firstDormantColumn,
  }) {
    final stage = stages[firstOperation]!;
    final values = operations._operations!;
    final operation = values[firstOperation];
    final suffix = values[firstOperation + 1];
    final suffixAlpha = suffix.opacity.clamp(0.0, 1.0);
    final suffixCosine = suffix.cosine * suffix.scale;
    final suffixSine = suffix.sine * suffix.scale;
    if (operation.progress >= 1 || suffixAlpha == 0 || suffix.scale == 0) {
      return 0;
    }

    stage.updateFrame(operation, deferCurl: true);
    final width = _tileWidths;
    final height = _tileHeights;
    final centerX = _tileCentersX;
    final centerY = _tileCentersY;
    final stageX = stage.columnCenters;
    final stageY = stage.rowCenters;
    final spriteScale = bounds.width / sourceRegion.width;
    final pivotX = _pivot.dx;
    final pivotY = _pivot.dy;
    final horizontal = _sourceHorizontalEdges;
    final vertical = _sourceVerticalEdges;
    final lastColumn = firstDormantColumn ?? columns - 1;
    var target = 0;
    for (var row = 0; row < rows; row++) {
      final tileY = centerY[row];
      final anchorY = stageY[row];
      final halfHeight = height[row] / 2;
      final top = vertical[row];
      final bottom = vertical[row + 1];
      var particle = row * columns;
      for (var column = 0; column <= lastColumn; column++, particle++) {
        final alpha = (stage.opacity[particle] * suffixAlpha * 255).round();
        if (alpha == 0) continue;
        final tileScale = stage.scale[particle];
        final anchorX = stageX[column];
        final x = anchorX + (centerX[column] - anchorX) * tileScale + stage.offsetX[particle] - pivotX;
        final y = anchorY + (tileY - anchorY) * tileScale + stage.offsetY[particle] - pivotY;
        final a = suffixCosine * tileScale;
        final b = suffixSine * tileScale;
        final halfWidth = width[column] / 2;
        final offset = target * 4;
        transforms[offset] = a * spriteScale;
        transforms[offset + 1] = b * spriteScale;
        transforms[offset + 2] =
            (suffixCosine * x - suffixSine * y + pivotX + suffix.x) - a * halfWidth + b * halfHeight;
        transforms[offset + 3] =
            (suffixSine * x + suffixCosine * y + pivotY + suffix.y) - b * halfWidth - a * halfHeight;
        rects[offset] = horizontal[column];
        rects[offset + 1] = top;
        rects[offset + 2] = horizontal[column + 1];
        rects[offset + 3] = bottom;
        colors[target++] = alpha << 24;
      }
      if (firstDormantColumn != null) {
        assert(stage.opacity[particle - 1] == 1, 'A merged row must start at a fully opaque dormant particle.');
        // Extend the first dormant quad across the rest of the row.
        rects[(target - 1) * 4 + 2] = horizontal[columns];
      }
    }
    return target;
  }

  late final Float64List _tileWidths = _lengths(_horizontalEdges);
  late final Float64List _tileHeights = _lengths(_verticalEdges);
  late final Float64List _tileCentersX = _centers(_horizontalEdges, _tileWidths);
  late final Float64List _tileCentersY = _centers(_verticalEdges, _tileHeights);

  static Float64List _lengths(List<double> edges) {
    final result = Float64List(edges.length - 1);
    for (var i = 0; i < result.length; i++) {
      result[i] = edges[i + 1] - edges[i];
    }
    return result;
  }

  static Float64List _centers(List<double> edges, Float64List lengths) {
    final result = Float64List(lengths.length);
    for (var i = 0; i < result.length; i++) {
      result[i] = edges[i] + lengths[i] / 2;
    }
    return result;
  }

  int _writeNativeFirstPose(
    Float32List transforms,
    Float32List rects,
    Int32List colors, {
    required int firstDormantColumn,
  }) {
    validate();
    final stage = stages[firstOperation]!;
    final values = operations._operations!;
    final operation = values[firstOperation];
    final suffix = values[firstOperation + 1];
    final progress = operation.progress;
    final directionX = operation.directionX;
    final directionY = operation.directionY;
    final moves = directionX != 0 || directionY != 0;
    final defer = stage.columns > 1 && progress < 0.1;
    final curlColumns = defer ? (moves ? stage._potentiallyActiveColumns(progress) : 0) : stage.columns;
    stage._allocateParticleBuffers();
    final motion = _MotionDisintegrationParameters.geometryParameters;
    final samples = _MotionDisintegrationTable.samples;
    final columnCenters = stage.columnCenters;
    final rowCenters = stage.rowCenters;
    final tileCentersX = _tileCentersX;
    final tileCentersY = _tileCentersY;
    final tileWidths = _tileWidths;
    final tileHeights = _tileHeights;
    final horizontalEdges = _sourceHorizontalEdges;
    final verticalEdges = _sourceVerticalEdges;
    final count = MotionParticleAbi.fillNativeFirstPose(
      stage.columns,
      stage.rows,
      curlColumns,
      firstParticle,
      _MotionDisintegrationParameters.seed,
      moves ? 1 : 0,
      _MotionDisintegrationTable.sampleCount,
      firstDormantColumn,
      stage.bounds.width,
      progress,
      -(directionX + directionY) * math.sqrt(0.5),
      (directionX - directionY) * math.sqrt(0.5),
      _pivot.dx,
      _pivot.dy,
      suffix.cosine * suffix.scale,
      suffix.sine * suffix.scale,
      suffix.x,
      suffix.y,
      bounds.width / sourceRegion.width,
      suffix.opacity.clamp(0.0, 1.0),
      motion,
      samples,
      columnCenters,
      rowCenters,
      tileCentersX,
      tileCentersY,
      tileWidths,
      tileHeights,
      stage._delay,
      stage._lifetime,
      stage._driftX,
      stage._driftY,
      stage._curlSine,
      stage._curlCosine,
      stage.scale,
      stage.opacity,
      stage.offsetX,
      stage.offsetY,
      horizontalEdges,
      verticalEdges,
      transforms,
      rects,
      colors,
    );
    stage
      .._previousProgress = progress
      .._previousDirectionX = directionX
      .._previousDirectionY = directionY
      .._preparedCurlColumns = curlColumns
      .._particlesReady = true;
    return count;
  }

  int _writeNativeTerminalPose(
    Float32List transforms,
    Float32List rects,
    Int32List colors, {
    required int firstDormantColumn,
    required bool omitZero,
  }) {
    validate();
    final stage = stages[firstOperation]!;
    final values = operations._operations!;
    final operation = values[firstOperation];
    final suffix = values[firstOperation + 1];
    final progress = operation.progress;
    final directionX = operation.directionX;
    final directionY = operation.directionY;
    final moves = directionX != 0 || directionY != 0;
    final update =
        stage._previousProgress != progress ||
        stage._previousDirectionX != directionX ||
        stage._previousDirectionY != directionY;
    final oldCurl = stage._preparedCurlColumns;
    final curlColumns = update && moves && oldCurl < stage.columns
        ? math.max(oldCurl, stage._potentiallyActiveColumns(progress))
        : oldCurl;
    final count = MotionParticleAbi.fillNativeTerminalPose(
      stage.columns,
      stage.rows,
      oldCurl,
      curlColumns,
      firstParticle,
      moves ? 1 : 0,
      _MotionDisintegrationTable.sampleCount,
      firstDormantColumn,
      omitZero ? 1 : 0,
      update ? 1 : 0,
      progress,
      -(directionX + directionY) * math.sqrt(0.5),
      (directionX - directionY) * math.sqrt(0.5),
      _pivot.dx,
      _pivot.dy,
      suffix.cosine * suffix.scale,
      suffix.sine * suffix.scale,
      suffix.x,
      suffix.y,
      bounds.width / sourceRegion.width,
      suffix.opacity.clamp(0.0, 1.0),
      _MotionDisintegrationTable.samples,
      stage.columnCenters,
      stage.rowCenters,
      _tileCentersX,
      _tileCentersY,
      _tileWidths,
      _tileHeights,
      stage._delay,
      stage._lifetime,
      stage._driftX,
      stage._driftY,
      stage._curlSine,
      stage._curlCosine,
      stage.scale,
      stage.opacity,
      stage.offsetX,
      stage.offsetY,
      _sourceHorizontalEdges,
      _sourceVerticalEdges,
      transforms,
      rects,
      colors,
    );
    if (update) {
      stage
        .._previousProgress = progress
        .._previousDirectionX = directionX
        .._previousDirectionY = directionY
        .._preparedCurlColumns = curlColumns;
    }
    return count;
  }

  void write(Float32List transforms, Int32List colors, {int? end}) {
    validate();
    final operationEnd = end ?? operations._operationCount;
    // A frozen source has already applied all preceding operations to its pixels.
    // With just one stage left every atlas cell maps directly to one particle.
    final frozenStage = operationEnd == operations._operationCount && firstOperation == operationEnd - 2
        ? stages[firstOperation]
        : null;
    if (frozenStage != null) {
      _writeFrozenStage(frozenStage, transforms, colors);
      return;
    }
    prepareAnchors(operationEnd);
    for (var index = 0; index < count; index++) {
      final column = index % columns;
      final row = index ~/ columns;
      final width = _horizontalEdges[column + 1] - _horizontalEdges[column];
      final height = _verticalEdges[row + 1] - _verticalEdges[row];
      final x = _horizontalEdges[column] + width / 2;
      final y = _verticalEdges[row] + height / 2;
      _evaluate(x, y, operationEnd);
      final offset = (firstParticle + index) * 4;
      transforms[offset] = _scaleCosine * bounds.width / sourceRegion.width;
      transforms[offset + 1] = _scaleSine * bounds.width / sourceRegion.width;
      transforms[offset + 2] = _x - _scaleCosine * width / 2 + _scaleSine * height / 2;
      transforms[offset + 3] = _y - _scaleSine * width / 2 - _scaleCosine * height / 2;
      colors[firstParticle + index] = (_opacity.clamp(0.0, 1.0) * 255).round() << 24;
    }
  }
}
