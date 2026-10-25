import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/geometry/contour_geometry_cache.dart';

import 'contour_geometry_test_data.dart';

void main() {
  test('when declared geometry is copied, it should preserve holes and ignore later caller mutations', () {
    final path = ui.Path()
      ..fillType = ui.PathFillType.evenOdd
      ..addRect(const ui.Rect.fromLTWH(0, 0, 20, 20))
      ..addRect(const ui.Rect.fromLTWH(5, 5, 10, 10));
    final source = ContourGeometry.declared(path);
    path.reset();
    expect(
      (source.bounds, source.shape.contains(const ui.Offset(2, 2)), source.shape.contains(const ui.Offset(10, 10))),
      (const ui.Rect.fromLTWH(0, 0, 20, 20), true, false),
    );
  });

  test('when a capture becomes logical geometry, it should preserve its source bounds', () {
    final source = ContourGeometryCache.test().obtain(
      ContourGeometryTestData.rectangle(left: 6, top: 9, scale: 3),
      pixelRatio: 3,
      origin: const ui.Offset(-1, -2),
    );
    expect(source.bounds, const ui.Rect.fromLTWH(1, 1, 12, 12));
  });

  test('when caller arrays change afterward, it should keep accepted coordinates unchanged', () {
    final input = ContourGeometryTestData.rectangle();
    final source = ContourGeometryCache.test().obtain(input, pixelRatio: 1);
    input.first[0] = 999;
    expect(source.shape.contains(const ui.Offset(6, 6)), isTrue);
  });

  test('when separate closed boundaries define a hole, it should preserve even-odd fill', () {
    final source = ContourGeometryCache.test().obtain([
      ...ContourGeometryTestData.rectangle(),
      ...ContourGeometryTestData.rectangle(left: 3, top: 3, scale: .5),
    ], pixelRatio: 1);
    expect((source.shape.contains(const ui.Offset(1, 1)), source.shape.contains(const ui.Offset(6, 6))), (true, false));
  });
}
