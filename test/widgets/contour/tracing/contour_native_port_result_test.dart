import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_result.dart';

void main() {
  test('when native contours share coordinate storage, it should return sublist views without a second copy', () {
    final values = Float64List.fromList([1, 2, 3, 4, 5, 6]);
    final result = ContourNativePortResult(
      ticket: 7,
      status: 0,
      lengths: Uint32List.fromList([2, 4]),
      values: values,
    );
    values[3] = 40;
    expect(
      [
        result.ticket,
        result.status,
        result.contours.map((contour) => contour.toList()).toList(),
      ],
      [
        7,
        0,
        [
          [1.0, 2.0],
          [3.0, 40.0, 5.0, 6.0],
        ],
      ],
    );
  });

  test('when the native reply has no geometry, it should preserve its failure status', () {
    final result = ContourNativePortResult(
      ticket: 9,
      status: 4,
      lengths: Uint32List(0),
      values: Float64List(0),
    );
    expect(
      (result.ticket, result.status, result.contours.isEmpty),
      (9, 4, true),
    );
  });

  test('when native lengths exceed the reply storage, it should reject the malformed reply', () {
    expect(
      () => ContourNativePortResult(
        ticket: 1,
        status: 0,
        lengths: Uint32List.fromList([3]),
        values: Float64List(2),
      ),
      throwsFormatException,
    );
  });

  test('when native lengths leave unused coordinates, it should reject the malformed reply', () {
    expect(
      () => ContourNativePortResult(
        ticket: 1,
        status: 0,
        lengths: Uint32List.fromList([1]),
        values: Float64List(2),
      ),
      throwsFormatException,
    );
  });

  test('when geometry metadata is published, it should prevent changes to the contour list', () {
    final result = ContourNativePortResult(
      ticket: 1,
      status: 0,
      lengths: Uint32List(0),
      values: Float64List(0),
    );
    expect(() => result.contours.add(Float64List(0)), throwsUnsupportedError);
  });
}
