part of '../../motion.dart';

class _MotionParticleRaster {
  new(this.image, this.fragment, {this.filterQuality = FilterQuality.none});

  final ui.Image image;
  final _MotionParticleFragment fragment;
  final FilterQuality filterQuality;
  late final _transforms = Float32List(fragment.count * 4);
  late final _colors = Int32List(fragment.count);
  late final _sourceRects = Float32List(fragment.count * 4);
  final _intactTransform = Float32List(4);
  final _intactColor = Int32List(1);
  late final Float32List _intactRect = _sourceRectsForIntact();
  bool _intact = false;
  bool _sourceRectsAreFull = false;
  int? _compactedCount;

  Float32List _sourceRectsForIntact() {
    final region = fragment.sourceRegion;
    return Float32List.fromList([region.left, region.top, region.right, region.bottom]);
  }

  bool prepare({int? end, bool allowPruning = false}) {
    final operations = fragment.operations;
    final values = operations._operations!;
    final operationEnd = end ?? operations._operationCount;
    _intact = true;
    _compactedCount = null;
    var opacity = 1.0;
    var a = 1.0;
    var b = 0.0;
    var x = fragment.bounds.left - fragment._pivot.dx;
    var y = fragment.bounds.top - fragment._pivot.dy;
    for (var index = fragment.firstOperation; index < operationEnd; index++) {
      final operation = values[index];
      if (operation.kind == .disintegrate) {
        if (operation.progress >= 1) return false;
        _intact = _intact && operation.progress == 0;
        continue;
      }
      opacity *= operation.opacity.clamp(0.0, 1.0);
      final cosine = operation.cosine * operation.scale;
      final sine = operation.sine * operation.scale;
      final previousX = x;
      final previousA = a;
      x = cosine * x - sine * y + operation.x;
      y = sine * previousX + cosine * y + operation.y;
      a = cosine * a - sine * b;
      b = sine * previousA + cosine * b;
    }
    if (opacity == 0 || (a == 0 && b == 0)) return false;

    if (_intact) {
      _intactColor[0] = (opacity * 255).round() << 24;
      if (_intactColor[0] == 0) return false;
      _intactTransform[0] = a * fragment.bounds.width / fragment.sourceRegion.width;
      _intactTransform[1] = b * fragment.bounds.width / fragment.sourceRegion.width;
      _intactTransform[2] = x + fragment._pivot.dx;
      _intactTransform[3] = y + fragment._pivot.dy;
      return true;
    }

    final stage = fragment.firstOperation;
    final terminal = allowPruning && end == null && stage > 0 && stage == operationEnd - 2;
    final particleStage = terminal ? fragment.stages[stage]! : null;
    final hasRegularGrid =
        particleStage != null && particleStage.columns == fragment.columns && particleStage.rows == fragment.rows;
    final useNativeUpdate = hasRegularGrid && particleStage._particlesReady && MotionParticleAbi.canWriteFrozenPose;
    if (particleStage != null) {
      final progress = values[stage].progress;
      final suffix = values[stage + 1];
      int? firstDormantColumn;
      // Join row tails only when the bilinear source fills its backing
      // image, with one whole texel per logical pixel.
      if (progress < _MotionDisintegrationParameters.columnDelay &&
          filterQuality == FilterQuality.low &&
          a == 1 &&
          b == 0 &&
          opacity == 1 &&
          suffix.x == 0 &&
          suffix.y == 0 &&
          fragment.bounds.width == fragment.sourceRegion.width &&
          fragment.bounds.height == fragment.sourceRegion.height &&
          fragment.sourceRegion.width == image.width &&
          fragment.sourceRegion.height == image.height) {
        final column = particleStage._potentiallyActiveColumns(progress);
        if (column < fragment.columns - 1) firstDormantColumn = column;
      }

      // Near the end of breakup, compact away particles that have faded out.
      final omitZero = progress >= 0.64;
      if (firstDormantColumn != null || omitZero) {
        _sourceRectsAreFull = false;
        final useNativeFirst =
            firstDormantColumn != null &&
            hasRegularGrid &&
            !particleStage._particlesReady &&
            MotionParticleAbi.canWriteFrozenPose;
        final int count;
        if (useNativeFirst) {
          count = fragment._writeNativeFirstPose(
            _transforms,
            _sourceRects,
            _colors,
            firstDormantColumn: firstDormantColumn,
          );
        } else if (useNativeUpdate) {
          count = fragment._writeNativeTerminalPose(
            _transforms,
            _sourceRects,
            _colors,
            firstDormantColumn: firstDormantColumn ?? -1,
            omitZero: omitZero,
          );
        } else {
          count = fragment.writeLiveFrozenStage(
            _transforms,
            _sourceRects,
            _colors,
            firstDormantColumn: firstDormantColumn,
          );
        }
        _compactedCount = count;
        return count != 0;
      }
    }

    if (useNativeUpdate) {
      fragment._writeNativeTerminalPose(
        _transforms,
        _sourceRects,
        _colors,
        firstDormantColumn: -1,
        omitZero: false,
      );
    } else {
      fragment.write(_transforms, _colors, end: end);
    }
    if (!_sourceRectsAreFull) {
      fragment.writeSourceRects(_sourceRects);
      _sourceRectsAreFull = true;
    }
    return true;
  }

  void paint(Canvas canvas, Paint paint) {
    paint.filterQuality = filterQuality;
    final count = _compactedCount;
    if (count != null && count < fragment.count) {
      canvas.drawRawAtlas(
        image,
        Float32List.sublistView(_transforms, 0, count * 4),
        Float32List.sublistView(_sourceRects, 0, count * 4),
        Int32List.sublistView(_colors, 0, count),
        .srcIn,
        null,
        paint,
      );
      return;
    }
    canvas.drawRawAtlas(
      image,
      _intact ? _intactTransform : _transforms,
      _intact ? _intactRect : _sourceRects,
      _intact ? _intactColor : _colors,
      .srcIn,
      null,
      paint,
    );
  }

  Rect? visibleBounds() {
    final colors = _intact ? _intactColor : _colors;
    final transforms = _intact ? _intactTransform : _transforms;
    final sourceRects = _intact ? _intactRect : _sourceRects;
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (var index = 0; index < (_compactedCount ?? colors.length); index++) {
      if (colors[index] == 0) continue;
      final offset = index * 4;
      final a = transforms[offset];
      final b = transforms[offset + 1];
      final x = transforms[offset + 2];
      final y = transforms[offset + 3];
      final width = sourceRects[offset + 2] - sourceRects[offset];
      final height = sourceRects[offset + 3] - sourceRects[offset + 1];
      left = math.min(left, x + math.min(0, a * width) + math.min(0, -b * height));
      top = math.min(top, y + math.min(0, b * width) + math.min(0, a * height));
      right = math.max(right, x + math.max(0, a * width) + math.max(0, -b * height));
      bottom = math.max(bottom, y + math.max(0, b * width) + math.max(0, a * height));
    }
    if (!left.isFinite || left >= right || top >= bottom) return null;
    return Rect.fromLTRB(left, top, right, bottom);
  }
}
