part of 'contour.dart';

class _ContourCurveSimplifier {
  new _(this._curve, this._tolerance);

  final Float64List _curve;
  final double _tolerance;
  late final Float64List _output = Float64List(_curve.length);
  final _candidate = Float64List(8);
  int _cursor = 2;

  static Float64List simplify(Float64List curve, {required double pixelRatio}) {
    // Very small loops carry details such as accents and punctuation. Keeping
    // their existing cubics also avoids fitting overhead where it saves little.
    if (curve.length < 98) return curve;
    return _ContourCurveSimplifier._(curve, .05 * pixelRatio)._simplify();
  }

  Float64List _simplify() {
    _output[0] = _curve[0];
    _output[1] = _curve[1];
    final count = (_curve.length - 2) ~/ 6;
    // Fitting a closed loop in one pass gives coincident endpoints. Start with
    // quarters and preserve the existing tangent at every accepted join.
    for (var quarter = 0; quarter < 4; quarter++) {
      _range(count * quarter ~/ 4, count * (quarter + 1) ~/ 4);
    }
    return Float64List.fromList(Float64List.sublistView(_output, 0, _cursor));
  }

  void _range(int first, int end) {
    if (end - first == 1) {
      for (var j = first * 6 + 2; j < first * 6 + 8; j++) {
        _output[_cursor++] = _curve[j];
      }
      return;
    }
    if (_fit(first, end)) {
      for (var j = 2; j < 8; j++) {
        _output[_cursor++] = _candidate[j];
      }
      return;
    }
    final middle = (first + end) ~/ 2;
    _range(first, middle);
    _range(middle, end);
  }

  bool _fit(int first, int end) {
    final count = end - first;
    final base = first * 6;
    final last = end * 6;
    final x0 = _curve[base];
    final y0 = _curve[base + 1];
    final x3 = _curve[last];
    final y3 = _curve[last + 1];
    var tx0 = _curve[base + 2] - x0;
    var ty0 = _curve[base + 3] - y0;
    var tx1 = _curve[last - 2] - x3;
    var ty1 = _curve[last - 1] - y3;
    final length0 = math.sqrt(tx0 * tx0 + ty0 * ty0);
    final length1 = math.sqrt(tx1 * tx1 + ty1 * ty1);
    if (length0 == 0 || length1 == 0) return false;
    tx0 /= length0;
    ty0 /= length0;
    tx1 /= length1;
    ty1 /= length1;
    final dot = tx0 * tx1 + ty0 * ty1;
    // Keep endpoint positions and tangent directions fixed. Solve only the two
    // handle lengths, fitting existing endpoints and midpoints by least squares.
    var c00 = 0.0;
    var c01 = 0.0;
    var c11 = 0.0;
    var rhs0 = 0.0;
    var rhs1 = 0.0;
    for (var i = 1; i < count * 2; i++) {
      final point = (first + i ~/ 2) * 6;
      final midpoint = i.isOdd;
      final px = midpoint
          ? (_curve[point] + 3 * _curve[point + 2] + 3 * _curve[point + 4] + _curve[point + 6]) / 8
          : _curve[point];
      final py = midpoint
          ? (_curve[point + 1] + 3 * _curve[point + 3] + 3 * _curve[point + 5] + _curve[point + 7]) / 8
          : _curve[point + 1];
      final t = i / (count * 2);
      final u = 1 - t;
      final a = 3 * u * u * t;
      final b = 3 * u * t * t;
      final rx = px - u * u * (1 + 2 * t) * x0 - t * t * (3 - 2 * t) * x3;
      final ry = py - u * u * (1 + 2 * t) * y0 - t * t * (3 - 2 * t) * y3;
      c00 += a * a;
      c01 += a * b * dot;
      c11 += b * b;
      rhs0 += a * (tx0 * rx + ty0 * ry);
      rhs1 += b * (tx1 * rx + ty1 * ry);
    }
    final determinant = c00 * c11 - c01 * c01;
    if (determinant <= 1e-12) return false;
    final handle0 = (rhs0 * c11 - rhs1 * c01) / determinant;
    final handle1 = (c00 * rhs1 - c01 * rhs0) / determinant;
    // A reversed handle would turn a smooth join into a cusp.
    if (handle0 <= 0 || handle1 <= 0) return false;
    final x1 = x0 + handle0 * tx0;
    final y1 = y0 + handle0 * ty0;
    final x2 = x3 + handle1 * tx1;
    final y2 = y3 + handle1 * ty1;
    // Restrict the fitted cubic to each original cubic's parameter interval.
    // Their difference is another cubic. Its Bernstein control hull bounds the
    // complete curve, so accepted fits cannot hide errors between samples. The
    // .05 logical pixel bound stays far below antialias coverage at normal size.
    final toleranceSquared = _tolerance * _tolerance;
    for (var i = 0; i < count; i++) {
      final a = i / count;
      final b = (i + 1) / count;
      final ax = _evaluate(x0, x1, x2, x3, a);
      final ay = _evaluate(y0, y1, y2, y3, a);
      final bx = _evaluate(x0, x1, x2, x3, b);
      final by = _evaluate(y0, y1, y2, y3, b);
      final aa = _derivativeThird(x0, x1, x2, x3, a) / count;
      final ab = _derivativeThird(y0, y1, y2, y3, a) / count;
      final ba = _derivativeThird(x0, x1, x2, x3, b) / count;
      final bb = _derivativeThird(y0, y1, y2, y3, b) / count;
      final original = (first + i) * 6;
      if (!_close(ax, ay, _curve[original], _curve[original + 1], toleranceSquared) ||
          !_close(ax + aa, ay + ab, _curve[original + 2], _curve[original + 3], toleranceSquared) ||
          !_close(bx - ba, by - bb, _curve[original + 4], _curve[original + 5], toleranceSquared) ||
          !_close(bx, by, _curve[original + 6], _curve[original + 7], toleranceSquared)) {
        return false;
      }
    }
    _candidate[0] = x0;
    _candidate[1] = y0;
    _candidate[2] = x1;
    _candidate[3] = y1;
    _candidate[4] = x2;
    _candidate[5] = y2;
    _candidate[6] = x3;
    _candidate[7] = y3;
    return true;
  }

  static bool _close(double ax, double ay, double bx, double by, double toleranceSquared) {
    final dx = ax - bx;
    final dy = ay - by;
    return dx * dx + dy * dy <= toleranceSquared;
  }

  static double _evaluate(double a, double b, double c, double d, double t) {
    final u = 1 - t;
    return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d;
  }

  static double _derivativeThird(double a, double b, double c, double d, double t) {
    final u = 1 - t;
    return u * u * (b - a) + 2 * u * t * (c - b) + t * t * (d - c);
  }
}
