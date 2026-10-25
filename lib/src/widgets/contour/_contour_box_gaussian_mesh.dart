part of 'contour.dart';

class _ContourBoxGaussianMesh {
  new(Float32List values, double halfHeight) {
    final timer = Stopwatch()..start();
    final extentX = values[3] + 4.5;
    final extentY = halfHeight + 4.5;
    final columns = (extentX * 4).ceil();
    final rows = (extentY * 4).ceil();
    vertexCount = (columns + 1) * (rows + 1);
    triangleCount = columns * rows * 2;
    // Evaluate each axis after Float32 quantization, exactly as the submitted
    // vertices do. The Gaussian cap terms separate into columns and rows.
    final xs = Float32List(columns + 1);
    final ys = Float32List(rows + 1);
    final horizontal = Float64List((columns + 1) * 5);
    final vertical = Float64List((rows + 1) * 5);
    const sqrtHalf = 0.7071067811865475;
    for (var x = 0; x <= columns; x++) {
      xs[x] = -extentX + extentX * 2 * x / columns;
      final position = xs[x];
      horizontal[x * 5] = _erf((values[3] - position) * sqrtHalf) - _erf((-values[3] - position) * sqrtHalf);
      for (var i = 0; i < 4; i++) {
        horizontal[x * 5 + i + 1] =
            (_erf((values[9 + i] - position) * sqrtHalf) - _erf((-values[9 + i] - position) * sqrtHalf)) * 0.5;
      }
    }
    for (var y = 0; y <= rows; y++) {
      ys[y] = -extentY + extentY * 2 * y / rows;
      final position = ys[y];
      vertical[y * 5] = _erf((values[4] - position) * sqrtHalf) - _erf((-values[4] - position) * sqrtHalf);
      for (var i = 0; i < 4; i++) {
        final upper = values[5 + i] - position;
        final lower = values[5 + i] + position;
        vertical[y * 5 + i + 1] = math.exp(-0.5 * upper * upper) + math.exp(-0.5 * lower * lower);
      }
    }
    coefficientMicroseconds = timer.elapsedMicroseconds;
    final positions = Float32List(vertexCount * 2);
    final colors = Int32List(vertexCount);
    final scale = values[13];
    const weight0 = 0.3478548451374538;
    const weight1 = 0.6521451548625461;
    const weight2 = 0.6521451548625461;
    const weight3 = 0.3478548451374538;
    var index = 0;
    for (var y = 0; y <= rows; y++) {
      final rowY = ys[y];
      final rowBase = y * 5;
      final row0 = vertical[rowBase];
      final row1 = vertical[rowBase + 1];
      final row2 = vertical[rowBase + 2];
      final row3 = vertical[rowBase + 3];
      final row4 = vertical[rowBase + 4];
      for (var x = 0; x <= columns; x++) {
        final columnBase = x * 5;
        positions[index * 2] = xs[x];
        positions[index * 2 + 1] = rowY;
        var coverage = horizontal[columnBase] * row0 * 0.25;
        coverage += scale * horizontal[columnBase + 1] * row1 * weight0;
        coverage += scale * horizontal[columnBase + 2] * row2 * weight1;
        coverage += scale * horizontal[columnBase + 3] * row3 * weight2;
        coverage += scale * horizontal[columnBase + 4] * row4 * weight3;
        final bounded = coverage < 0.0
            ? 0.0
            : coverage > 1.0
            ? 1.0
            : coverage;
        colors[index] = (bounded * 255.0).round() << 24;
        index++;
      }
    }
    final indices = Uint16List(rows * (columns + 1) * 2 + (rows - 1) * 2);
    var offset = 0;
    final stride = columns + 1;
    for (var y = 0; y < rows; y++) {
      if (y != 0) {
        indices[offset] = indices[offset - 1];
        offset++;
        indices[offset++] = (y + 1) * stride;
      }
      for (var x = 0; x <= columns; x++) {
        indices[offset++] = (y + 1) * stride + x;
        indices[offset++] = y * stride + x;
      }
    }
    bytes = positions.lengthInBytes + colors.lengthInBytes + indices.lengthInBytes;
    final beforeNative = timer.elapsedMicroseconds;
    arrayMicroseconds = beforeNative - coefficientMicroseconds;
    vertices = ui.Vertices.raw(ui.VertexMode.triangleStrip, positions, colors: colors, indices: indices);
    generationMicroseconds = timer.elapsedMicroseconds;
    nativeVerticesMicroseconds = generationMicroseconds - beforeNative;
  }

  late final ui.Vertices vertices;
  late final int vertexCount;
  late final int triangleCount;
  late final int bytes;
  late final int generationMicroseconds;
  late final int coefficientMicroseconds;
  late final int arrayMicroseconds;
  late final int nativeVerticesMicroseconds;
  int references = 0;
  late final (double, double, double) cacheKey;

  static double _erf(double value) {
    final a = value.abs();
    var p = 1 + (0.278393 + (0.230389 + 0.078108 * a * a) * a) * a;
    p *= p;
    return value.sign * (1 - 1 / (p * p));
  }
}
