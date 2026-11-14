part of '../../motion.dart';

class _MotionParticleStage {
  new({required this.bounds, required double particleSize, required int budget}) {
    final cellSize = math.max(particleSize, math.sqrt(bounds.width * bounds.height / budget));
    columns = math.min((bounds.width / cellSize).ceil(), budget);
    rows = math.max(1, math.min((bounds.height / cellSize).ceil(), budget ~/ columns));
    centerX = Float64List(count);
    centerY = Float64List(count);
    _delay = Float64List(count);
    _lifetime = Float64List(count);
    _driftX = Float64List(count);
    _driftY = Float64List(count);
    _curlSine = Float64List(count);
    _curlCosine = Float64List(count);
    anchorX = Float64List(count);
    anchorY = Float64List(count);
    scale = Float64List(count);
    opacity = Float64List(count);
    offsetX = Float64List(count);
    offsetY = Float64List(count);
    var random = _MotionDisintegrationParameters.seed;
    double next() {
      random ^= (random << 13) & 0xffffffff;
      random ^= random >> 17;
      random ^= (random << 5) & 0xffffffff;
      return (random & 0xffffffff) / 4294967296;
    }

    final rounded = Float32List(1);
    double float(double value) {
      rounded[0] = value;
      return rounded[0];
    }

    for (var particle = 0; particle < count; particle++) {
      final column = particle % columns;
      final row = particle ~/ columns;
      centerX[particle] = bounds.left + (column + 0.5) * bounds.width / columns;
      centerY[particle] = bounds.top + (row + 0.5) * bounds.height / rows;
      final delay =
          column / columns * _MotionDisintegrationParameters.columnDelay +
          next() * _MotionDisintegrationParameters.randomDelay;
      _delay[particle] = float(delay);
      _lifetime[particle] = float(
        _MotionDisintegrationParameters.lifetimeBase + next() * (_MotionDisintegrationParameters.lifetimeRange - delay),
      );
      _driftX[particle] = float(
        -bounds.width *
            (_MotionDisintegrationParameters.horizontalDriftBase +
                next() * _MotionDisintegrationParameters.horizontalDriftRange),
      );
      _driftY[particle] = float(
        -bounds.width *
            (_MotionDisintegrationParameters.verticalDriftBase +
                next() * _MotionDisintegrationParameters.verticalDriftRange),
      );
      final phase = float(next() * math.pi * 2);
      final amplitude = float(
        bounds.width * (_MotionDisintegrationParameters.curlBase + next() * _MotionDisintegrationParameters.curlRange),
      );
      _curlSine[particle] = math.sin(phase) * amplitude;
      _curlCosine[particle] = math.cos(phase) * amplitude;
    }
  }

  final Rect bounds;
  late final int columns;
  late final int rows;
  late final Float64List centerX;
  late final Float64List centerY;
  late final Float64List anchorX;
  late final Float64List anchorY;
  late final Float64List scale;
  late final Float64List opacity;
  late final Float64List offsetX;
  late final Float64List offsetY;
  late final Float64List _delay;
  late final Float64List _lifetime;
  late final Float64List _driftX;
  late final Float64List _driftY;
  late final Float64List _curlSine;
  late final Float64List _curlCosine;

  int get count => columns * rows;

  int groupAt(double x, double y) {
    final column = ((x - bounds.left) / bounds.width * columns).floor().clamp(0, columns - 1);
    final row = ((y - bounds.top) / bounds.height * rows).floor().clamp(0, rows - 1);
    return row * columns + column;
  }

  void updateFrame(_MotionVisualOperation operation) {
    final samples = _MotionDisintegrationTable.samples;
    final moves = operation.directionX != 0 || operation.directionY != 0;
    final directionCosine = -(operation.directionX + operation.directionY) * math.sqrt(0.5);
    final directionSine = (operation.directionX - operation.directionY) * math.sqrt(0.5);
    for (var particle = 0; particle < count; particle++) {
      final life = ((operation.progress - _delay[particle]) / _lifetime[particle]).clamp(0.0, 1.0);
      final position = life * _MotionDisintegrationTable.sampleCount;
      final index = position.toInt();
      final tableOffset = index * _MotionDisintegrationTable.stride;
      final nextOffset = index == _MotionDisintegrationTable.sampleCount
          ? tableOffset
          : tableOffset + _MotionDisintegrationTable.stride;
      final fraction = position - index;
      scale[particle] = samples[tableOffset] + (samples[nextOffset] - samples[tableOffset]) * fraction;
      opacity[particle] = operation.progress >= 1
          ? 0
          : (samples[tableOffset + 1] + (samples[nextOffset + 1] - samples[tableOffset + 1]) * fraction) / 255;
      offsetX[particle] = 0;
      offsetY[particle] = 0;
      if (!moves) continue;
      final curlSine = samples[tableOffset + 2] + (samples[nextOffset + 2] - samples[tableOffset + 2]) * fraction;
      final curlCosine = samples[tableOffset + 3] + (samples[nextOffset + 3] - samples[tableOffset + 3]) * fraction;
      final x = _driftX[particle] * life + _curlSine[particle] * curlCosine + _curlCosine[particle] * curlSine;
      final y = _driftY[particle] * life + _curlCosine[particle] * curlCosine - _curlSine[particle] * curlSine;
      offsetX[particle] = x * directionCosine - y * directionSine;
      offsetY[particle] = x * directionSine + y * directionCosine;
    }
  }
}
