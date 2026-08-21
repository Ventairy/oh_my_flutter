part of 'maybe_safe_area.dart';

class _MaybeSafeAreaBounds {
  double left = 0;
  double top = 0;
  double right = 0;
  double bottom = 0;

  void setTransformed(
    Matrix4 transform, {
    required double width,
    required double height,
  }) {
    final storage = transform.storage;
    final wx = storage[0] * width;
    final hx = storage[4] * height;
    final rx = storage[12];
    final wy = storage[1] * width;
    final hy = storage[5] * height;
    final ry = storage[13];

    if (storage[3] == 0.0 && storage[7] == 0.0 && storage[15] == 1.0) {
      left = rx;
      right = rx;
      if (wx < 0) {
        left += wx;
      } else {
        right += wx;
      }
      if (hx < 0) {
        left += hx;
      } else {
        right += hx;
      }
      top = ry;
      bottom = ry;
      if (wy < 0) {
        top += wy;
      } else {
        bottom += wy;
      }
      if (hy < 0) {
        top += hy;
      } else {
        bottom += hy;
      }
      return;
    }

    final ww = storage[3] * width;
    final hw = storage[7] * height;
    final rw = storage[15];
    final ulx = rx / rw;
    final uly = ry / rw;
    final urx = (rx + wx) / (rw + ww);
    final ury = (ry + wy) / (rw + ww);
    final llx = (rx + hx) / (rw + hw);
    final lly = (ry + hy) / (rw + hw);
    final lrx = (rx + wx + hx) / (rw + ww + hw);
    final lry = (ry + wy + hy) / (rw + ww + hw);
    left = _min4(ulx, urx, llx, lrx);
    top = _min4(uly, ury, lly, lry);
    right = _max4(ulx, urx, llx, lrx);
    bottom = _max4(uly, ury, lly, lry);
  }

  static double _min4(double a, double b, double c, double d) {
    final e = a < b ? a : b;
    final f = c < d ? c : d;
    return e < f ? e : f;
  }

  static double _max4(double a, double b, double c, double d) {
    final e = a > b ? a : b;
    final f = c > d ? c : d;
    return e > f ? e : f;
  }
}
