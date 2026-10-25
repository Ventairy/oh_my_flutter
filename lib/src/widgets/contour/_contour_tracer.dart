part of 'contour.dart';

class _ContourTracer {
  // Ignore almost-transparent source paint so soft emoji fringes do not become
  // solid geometry and distort the contour beyond the visible artwork.
  static const double _minimumOpacity = .03;

  // Reject tiny faint fragments before normalizing their opacity; otherwise
  // nearly invisible emoji specks become prominent circles after stroking.
  // Opacity-weighted logical area keeps this gate independent of capture density.
  // Regions reaching 50% opacity bypass it to preserve punctuation and accents.
  static const double _minimumVisibleArea = .25;

  // Bound retained curves separately from the source image. Many opaque tiny
  // loops can produce much more geometry than their captured pixels occupy.
  static const int _maximumGeometryBytes = 4 * 1024 * 1024;
  static const int _contourMetadataBytes = 64;
  static const int _maximumContourPoints = 32768;

  static Future<_ContourTraceResult> trace(
    Uint8List rgba,
    int width,
    int height, {
    required double pixelRatio,
  }) async {
    final stride = width + 2;
    final rows = height + 2;
    final coverage = await _coverage(
      rgba,
      width,
      height,
      pixelRatio: pixelRatio,
    );

    // Each crossing belongs to two adjacent cells. Store the traversed sides
    // per cell, avoiding an allocated adjacency graph for every boundary pixel.
    final columns = stride - 1;
    final visited = Uint8List(columns * (rows - 1));
    final contours = <Float64List>[];
    var geometryBytes = 0;
    var tracedPoints = 0;
    const firstSides = [0, 1, 2, 2, 4, 1, 4, 4, 4, 4, 8, 4, 2, 2, 1, 0];
    // Each marching-square case maps an entering edge to its paired exit.
    // Pack top/right/bottom/left in successive nibbles; the checkerboard cases
    // contain two independent segments that must both survive traversal.
    const exits = [
      0x0,
      0x1008,
      0x12,
      0x2080,
      0x240,
      0x4812,
      0x104,
      0x4800,
      0x4800,
      0x104,
      0x1248,
      0x240,
      0x2080,
      0x12,
      0x1008,
      0x0,
    ];
    for (var y = 0; y + 1 < rows; y++) {
      for (var x = 0; x + 1 < stride; x++) {
        final index = y * stride + x;
        final bits = _bits(coverage, index, stride);
        if (bits == 0 || bits == 15) continue;
        var side = firstSides[bits];
        final cell = y * columns + x;
        if (visited[cell] & side != 0) {
          if (bits == 5) {
            side = 4;
          } else if (bits == 10) {
            side = 2;
          } else {
            continue;
          }
          if (visited[cell] & side != 0) continue;
        }
        final startX = x;
        final startY = y;
        final startSide = side;
        var cx = x;
        var cy = y;
        var currentBits = bits;
        final points = <Offset>[];
        do {
          // One winding boundary can grow large even when it is the only
          // contour. Stop before allocating another point beyond its allowance.
          if (points.length >= _maximumContourPoints) return const _ContourTraceResult.capacity();
          points.add(
            _position(
              side == 2 ? cx + 1 : cx,
              side == 4 ? cy + 1 : cy,
              side == 1 || side == 4,
              coverage,
              stride,
            ),
          );
          final shift = switch (side) {
            1 => 0,
            2 => 4,
            4 => 8,
            _ => 12,
          };
          final exit = (exits[currentBits] >> shift) & 15;
          if (exit == 0) throw StateError('no exit $currentBits $side');
          visited[cy * columns + cx] |= side | exit;
          switch (exit) {
            case 1:
              cy--;
              side = 4;
            case 2:
              cx++;
              side = 8;
            case 4:
              cy++;
              side = 1;
            case 8:
              cx--;
              side = 2;
          }
          currentBits = _bits(coverage, cy * stride + cx, stride);
          if (kIsWeb && ++tracedPoints % 4096 == 0) await Future<void>.delayed(Duration.zero);
        } while (cx != startX || cy != startY || side != startSide);
        if (points.length >= 3) {
          final curve = _curve(
            points,
            maximumBytes: _maximumGeometryBytes - geometryBytes - _contourMetadataBytes,
          );
          if (curve == null) return const _ContourTraceResult.capacity();
          final simplified = _ContourCurveSimplifier.simplify(curve, pixelRatio: pixelRatio);
          geometryBytes += simplified.lengthInBytes + _contourMetadataBytes;
          contours.add(simplified);
        }
      }
      if (kIsWeb && y % 16 == 0) await Future<void>.delayed(Duration.zero);
    }
    return _ContourTraceResult.success(contours);
  }

  static int _bits(Uint8List coverage, int index, int stride) =>
      (coverage[index] >= 128 ? 1 : 0) |
      (coverage[index + 1] >= 128 ? 2 : 0) |
      (coverage[index + stride + 1] >= 128 ? 4 : 0) |
      (coverage[index + stride] >= 128 ? 8 : 0);

  static Future<Uint8List> _coverage(
    Uint8List rgba,
    int width,
    int height, {
    required double pixelRatio,
  }) async {
    final stride = width + 2;
    final rows = height + 2;
    final mask = Uint8List(stride * rows);
    var nonzero = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final alpha = rgba[(y * width + x) * 4 + 3];
        mask[(y + 1) * stride + x + 1] = alpha;
        if (alpha != 0) nonzero++;
      }
      if (kIsWeb && y % 16 == 0) await Future<void>.delayed(Duration.zero);
    }

    if (nonzero == 0) return mask;
    final coverage = Uint8List(mask.length);
    final visited = Uint8List(mask.length);
    final component = Uint32List(nonzero);
    final opacityFloor = math.max(1, (_minimumOpacity * 255).ceil());
    final minimumAlphaArea = _minimumVisibleArea * 255 * pixelRatio * pixelRatio;
    // Yield by total work, so many small components do not each start a timer.
    var processedPixels = 0;
    for (var y = 1; y <= height; y++) {
      for (var x = 1; x <= width; x++) {
        final start = y * stride + x;
        if (mask[start] == 0 || visited[start] != 0) continue;
        var count = 1;
        var peak = 0;
        var alphaArea = 0;
        component[0] = start;
        visited[start] = 1;
        for (var head = 0; head < count; head++) {
          final index = component[head];
          peak = math.max(peak, mask[index]);
          alphaArea += mask[index];
          count = _enqueueNeighbors(mask, visited, component, index, stride, count);
          if (kIsWeb && ++processedPixels % 4096 == 0) await Future<void>.delayed(Duration.zero);
        }
        // Judge visibility before normalizing opacity. Dense, opaque details
        // bypass the area gate, so punctuation and fine accents survive.
        if (peak < opacityFloor || (peak < 128 && alphaArea < minimumAlphaArea)) continue;
        for (var pixel = 0; pixel < count; pixel++) {
          final index = component[pixel];
          final boundary =
              mask[index] < opacityFloor ||
              mask[index - stride - 1] < opacityFloor ||
              mask[index - stride] < opacityFloor ||
              mask[index - stride + 1] < opacityFloor ||
              mask[index - 1] < opacityFloor ||
              mask[index + 1] < opacityFloor ||
              mask[index + stride - 1] < opacityFloor ||
              mask[index + stride] < opacityFloor ||
              mask[index + stride + 1] < opacityFloor;
          // Only visibly supported interiors unite opacity changes. Faint
          // fringes retain their fractional coverage, even several pixels in.
          coverage[index] = boundary ? (mask[index] * 255 / peak).round() : 255;
          if (kIsWeb && ++processedPixels % 4096 == 0) await Future<void>.delayed(Duration.zero);
        }
      }
      if (kIsWeb && y % 16 == 0) await Future<void>.delayed(Duration.zero);
    }

    return coverage;
  }

  // Keep the fixed neighborhood scan synchronous, outside the web-yielding
  // flood fill, so every painted pixel needs neither an iterator nor nested
  // loop bookkeeping.
  static int _enqueueNeighbors(
    Uint8List mask,
    Uint8List visited,
    Uint32List component,
    int index,
    int stride,
    int count,
  ) {
    {
      final next = index - stride - 1;
      if (mask[next] != 0 && visited[next] == 0) {
        visited[next] = 1;
        component[count++] = next;
      }
    }
    {
      final next = index - stride;
      if (mask[next] != 0 && visited[next] == 0) {
        visited[next] = 1;
        component[count++] = next;
      }
    }
    {
      final next = index - stride + 1;
      if (mask[next] != 0 && visited[next] == 0) {
        visited[next] = 1;
        component[count++] = next;
      }
    }
    {
      final next = index - 1;
      if (mask[next] != 0 && visited[next] == 0) {
        visited[next] = 1;
        component[count++] = next;
      }
    }
    {
      final next = index + 1;
      if (mask[next] != 0 && visited[next] == 0) {
        visited[next] = 1;
        component[count++] = next;
      }
    }
    {
      final next = index + stride - 1;
      if (mask[next] != 0 && visited[next] == 0) {
        visited[next] = 1;
        component[count++] = next;
      }
    }
    {
      final next = index + stride;
      if (mask[next] != 0 && visited[next] == 0) {
        visited[next] = 1;
        component[count++] = next;
      }
    }
    {
      final next = index + stride + 1;
      if (mask[next] != 0 && visited[next] == 0) {
        visited[next] = 1;
        component[count++] = next;
      }
    }
    return count;
  }

  static Offset _position(int x, int y, bool horizontal, Uint8List coverage, int stride) {
    final first = coverage[y * stride + x];
    final second = coverage[y * stride + x + (horizontal ? 1 : stride)];
    final fraction = (127.5 - first) / (second - first);
    return Offset(x - .5 + (horizontal ? fraction : 0), y - .5 + (horizontal ? 0 : fraction));
  }

  static Float64List? _curve(List<Offset> points, {required int maximumBytes}) {
    final lengths = Float64List(points.length);
    var perimeter = 0.0;
    for (var index = 0; index < points.length; index++) {
      final start = points[index];
      final end = points[(index + 1) % points.length];
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final length = math.sqrt(dx * dx + dy * dy);
      lengths[index] = length;
      perimeter += length;
    }
    final count = math.max(4, (perimeter / 2).ceil());
    // Check the complete unsimplified curve before allocating its samples,
    // knots, or cubic output. Simplification can only reduce the retained size.
    if ((2 + count * 6) * Float64List.bytesPerElement > maximumBytes) return null;
    final samples = Float64List(count * 2);
    var edge = 0;
    var traversed = 0.0;
    for (var index = 0; index < count; index++) {
      final distance = perimeter * index / count;
      while (edge < lengths.length - 1 && traversed + lengths[edge] < distance) {
        traversed += lengths[edge++];
      }
      final fraction = lengths[edge] == 0 ? 0.0 : (distance - traversed) / lengths[edge];
      final start = points[edge];
      final end = points[(edge + 1) % points.length];
      samples[index * 2] = start.dx * (1 - fraction) + end.dx * fraction;
      samples[index * 2 + 1] = start.dy * (1 - fraction) + end.dy * fraction;
    }
    final knots = count < 8 ? samples : Float64List(count * 2);
    if (count >= 8) {
      for (var index = 0; index < count; index++) {
        var x = samples[index * 2];
        var y = samples[index * 2 + 1];
        var weight = 1.0;
        const weights = [.4111122905, .0285655008, .0003354626];
        for (var offset = 1; offset <= weights.length; offset++) {
          final contribution = weights[offset - 1];
          final previous = ((index + count - offset) % count) * 2;
          final next = ((index + offset) % count) * 2;
          x += (samples[previous] + samples[next]) * contribution;
          y += (samples[previous + 1] + samples[next + 1]) * contribution;
          weight += contribution * 2;
        }
        knots[index * 2] = x / weight;
        knots[index * 2 + 1] = y / weight;
      }
    }
    // Store a move followed by cubic controls and endpoints. Periodic
    // Catmull–Rom tangents agree at every join, including the closing segment.
    final curve = Float64List(2 + count * 6);
    curve[0] = knots[0];
    curve[1] = knots[1];
    for (var index = 0; index < count; index++) {
      final previous = ((index + count - 1) % count) * 2;
      final start = index * 2;
      final end = ((index + 1) % count) * 2;
      final next = ((index + 2) % count) * 2;
      final base = 2 + index * 6;
      curve[base] = knots[start] + (knots[end] - knots[previous]) / 6;
      curve[base + 1] = knots[start + 1] + (knots[end + 1] - knots[previous + 1]) / 6;
      curve[base + 2] = knots[end] - (knots[next] - knots[start]) / 6;
      curve[base + 3] = knots[end + 1] - (knots[next + 1] - knots[start + 1]) / 6;
      curve[base + 4] = knots[end];
      curve[base + 5] = knots[end + 1];
    }
    return curve;
  }
}
