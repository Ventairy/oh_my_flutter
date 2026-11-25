part of '../../motion.dart';

class _MotionParticleStage {
  new({required this.bounds, required int budget}) {
    final cellSize = math.max(
      MotionEffectTransform.defaultParticleSize,
      math.sqrt(bounds.width * bounds.height / budget),
    );
    columns = math.min((bounds.width / cellSize).ceil(), budget);
    rows = math.max(1, math.min((bounds.height / cellSize).ceil(), budget ~/ columns));
  }

  void prepareParticles({bool deferCurl = false}) {
    if (_particlesReady) return;
    _particlesReady = true;
    _preparedCurlColumns = deferCurl ? 0 : columns;
    _allocateParticleBuffers();
    final sample = MotionParticleAbi.isAndroidArm32 ? Float64List(1) : null;
    // At 2^20, the least significant bit of a double is worth 2^-32.
    final words = sample == null ? null : (Uint32List.view(sample.buffer)..[1] = 0x41300000);
    var random = _MotionDisintegrationParameters.seed;
    final curl = Float32List(2);
    for (var particle = 0; particle < count; particle++) {
      final column = particle % columns;
      random = _nextSeedWord(random);
      final delay =
          column / columns * _MotionDisintegrationParameters.columnDelay +
          _seedUniform(random, sample, words) * _MotionDisintegrationParameters.randomDelay;
      _delay[particle] = delay;
      random = _nextSeedWord(random);
      _lifetime[particle] =
          _MotionDisintegrationParameters.lifetimeBase +
          _seedUniform(random, sample, words) * (_MotionDisintegrationParameters.lifetimeRange - delay);
      random = _nextSeedWord(random);
      _driftX[particle] =
          -bounds.width *
          (_MotionDisintegrationParameters.horizontalDriftBase +
              _seedUniform(random, sample, words) * _MotionDisintegrationParameters.horizontalDriftRange);
      random = _nextSeedWord(random);
      _driftY[particle] =
          -bounds.width *
          (_MotionDisintegrationParameters.verticalDriftBase +
              _seedUniform(random, sample, words) * _MotionDisintegrationParameters.verticalDriftRange);
      random = _nextSeedWord(random);
      curl[0] = _seedUniform(random, sample, words) * math.pi * 2;
      random = _nextSeedWord(random);
      curl[1] =
          bounds.width *
          (_MotionDisintegrationParameters.curlBase +
              _seedUniform(random, sample, words) * _MotionDisintegrationParameters.curlRange);
      if (deferCurl) {
        // Keep the same rounded angle and radius until this column can move.
        _curlSine[particle] = curl[0];
        _curlCosine[particle] = curl[1];
      } else {
        _curlSine[particle] = math.sin(curl[0]) * curl[1];
        _curlCosine[particle] = math.cos(curl[0]) * curl[1];
      }
    }
  }

  void _allocateParticleBuffers() {
    _delay = Float32List(count);
    _lifetime = Float32List(count);
    _driftX = Float32List(count);
    _driftY = Float32List(count);
    _curlSine = Float64List(count);
    _curlCosine = Float64List(count);
    scale = Float64List(count);
    opacity = Float64List(count);
    offsetX = Float64List(count);
    offsetY = Float64List(count);
  }

  @pragma('vm:prefer-inline')
  static int _nextSeedWord(int seed) {
    var word = seed;
    word ^= (word << 13) & 0xffffffff;
    word ^= word >> 17;
    word ^= (word << 5) & 0xffffffff;
    return word;
  }

  @pragma('vm:prefer-inline')
  static double _seedUniform(int word, Float64List? sample, Uint32List? words) {
    if (MotionParticleAbi.isAndroidArm32) {
      words![0] = word;
      return sample![0] - 1048576.0;
    }
    return (word & 0xffffffff) / 4294967296;
  }

  final Rect bounds;
  late final int columns;
  late final int rows;
  late final Float64List columnCenters = _axisCenters(bounds.left, bounds.width, columns);
  late final Float64List rowCenters = _axisCenters(bounds.top, bounds.height, rows);
  late final Float64List anchorX = Float64List(count);
  late final Float64List anchorY = Float64List(count);
  late final Float64List scale;
  late final Float64List opacity;
  late final Float64List offsetX;
  late final Float64List offsetY;
  bool _particlesReady = false;
  int _preparedCurlColumns = 0;
  late final _roundedDelay = Float32List(1);
  double? _previousProgress;
  double _previousDirectionX = 0;
  double _previousDirectionY = 0;
  late final Float32List _delay;
  late final Float32List _lifetime;
  late final Float32List _driftX;
  late final Float32List _driftY;
  late final Float64List _curlSine;
  late final Float64List _curlCosine;

  int get count => columns * rows;

  Float64List _axisCenters(double origin, double length, int cells) {
    final centers = Float64List(cells);
    for (var index = 0; index < cells; index++) {
      centers[index] = origin + (index + 0.5) * length / cells;
    }
    return centers;
  }

  int groupAt(double x, double y) {
    final column = ((x - bounds.left) / bounds.width * columns).floor().clamp(0, columns - 1);
    final row = ((y - bounds.top) / bounds.height * rows).floor().clamp(0, rows - 1);
    return row * columns + column;
  }

  int _potentiallyActiveColumns(double progress) {
    const delay = _MotionDisintegrationParameters.columnDelay;
    var column = (progress * columns / delay).ceil().clamp(0, columns);
    // Round the earliest delay like the seeded per-particle delays.
    final rounded = _roundedDelay;
    while (column > 0) {
      rounded[0] = (column - 1) / columns * delay;
      if (rounded[0] < progress) break;
      column--;
    }
    while (column < columns) {
      rounded[0] = column / columns * delay;
      if (rounded[0] >= progress) break;
      column++;
    }
    return column;
  }

  void _prepareCurlThrough(int endColumn) {
    final firstColumn = _preparedCurlColumns;
    if (endColumn <= firstColumn) return;
    _preparedCurlColumns = endColumn;
    for (var row = 0; row < rows; row++) {
      final from = row * columns + firstColumn;
      final end = row * columns + endColumn;
      for (var particle = from; particle < end; particle++) {
        final angle = _curlSine[particle];
        final distance = _curlCosine[particle];
        _curlSine[particle] = math.sin(angle) * distance;
        _curlCosine[particle] = math.cos(angle) * distance;
      }
    }
  }

  void updateFrame(_MotionVisualOperation operation, {bool deferCurl = false}) {
    if (_previousProgress == operation.progress &&
        _previousDirectionX == operation.directionX &&
        _previousDirectionY == operation.directionY) {
      return;
    }
    final progress = operation.progress;
    prepareParticles(deferCurl: deferCurl && columns > 1 && progress < 0.1);
    _previousProgress = operation.progress;
    _previousDirectionX = operation.directionX;
    _previousDirectionY = operation.directionY;
    final samples = _MotionDisintegrationTable.samples;
    // Avoid converting the integer index to a boxed double for each moving particle.
    final positions = MotionParticleAbi.isAndroidArm32 ? _MotionDisintegrationTable.positions : null;
    final moves = operation.directionX != 0 || operation.directionY != 0;
    if (_preparedCurlColumns < columns && moves) {
      _prepareCurlThrough(_potentiallyActiveColumns(progress));
    }
    final directionCosine = -(operation.directionX + operation.directionY) * math.sqrt(0.5);
    final directionSine = (operation.directionX - operation.directionY) * math.sqrt(0.5);
    for (var particle = 0; particle < count; particle++) {
      final elapsed = progress - _delay[particle];
      if (elapsed <= 0) {
        scale[particle] = 1;
        opacity[particle] = 1;
        offsetX[particle] = 0;
        offsetY[particle] = 0;
        continue;
      }
      final life = (elapsed / _lifetime[particle]).clamp(0.0, 1.0);
      final position = life * _MotionDisintegrationTable.sampleCount;
      final index = position.toInt();
      final tableOffset = index * _MotionDisintegrationTable.stride;
      final nextOffset = index == _MotionDisintegrationTable.sampleCount
          ? tableOffset
          : tableOffset + _MotionDisintegrationTable.stride;
      final fraction = positions == null ? position - index : position - positions[index];
      scale[particle] = samples[tableOffset] + (samples[nextOffset] - samples[tableOffset]) * fraction;
      opacity[particle] = progress >= 1
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
