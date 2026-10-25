import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/geometry/contour_geometry_cache.dart';

import 'contour_geometry_test_data.dart';

void main() {
  test('when accepted coordinates repeat, it should reuse one immutable source', () {
    final cache = ContourGeometryCache.test();
    final first = cache.obtain(ContourGeometryTestData.rectangle(), pixelRatio: 1);
    expect(identical(cache.obtain(ContourGeometryTestData.rectangle(), pixelRatio: 1), first), isTrue);
  });

  test('when a different capture produces the same logical curves, it should reuse its source', () {
    final cache = ContourGeometryCache.test();
    final first = cache.obtain(ContourGeometryTestData.rectangle(), pixelRatio: 1);
    final second = cache.obtain(
      ContourGeometryTestData.rectangle(left: 4, top: 6, scale: 2),
      pixelRatio: 2,
      origin: const ui.Offset(-2, -3),
    );
    expect(identical(first, second), isTrue);
  });

  test('when complete hashes collide, it should compare every accepted coordinate', () {
    final cache = ContourGeometryCache.test(hashMask: 0);
    final first = cache.obtain(ContourGeometryTestData.rectangle(), pixelRatio: 1);
    final second = cache.obtain(ContourGeometryTestData.rectangle(left: 1), pixelRatio: 1);
    expect(identical(first, second), isFalse);
  });

  test('when a source is reused, it should keep native Path identity stable', () {
    final cache = ContourGeometryCache.test();
    final first = cache.obtain(ContourGeometryTestData.rectangle(), pixelRatio: 1);
    final second = cache.obtain(ContourGeometryTestData.rectangle(), pixelRatio: 1);
    expect(identical(first.shape, second.shape), isTrue);
  });

  test('when source retention reaches its count limit, it should evict the least recently used value', () {
    final cache = ContourGeometryCache.test(maximumSources: 2);
    final first = cache.obtain(ContourGeometryTestData.rectangle(), pixelRatio: 1);
    final second = cache.obtain(ContourGeometryTestData.rectangle(left: 1), pixelRatio: 1);
    cache
      ..obtain(ContourGeometryTestData.rectangle(), pixelRatio: 1)
      ..obtain(ContourGeometryTestData.rectangle(left: 2), pixelRatio: 1);
    final retained = identical(cache.obtain(ContourGeometryTestData.rectangle(), pixelRatio: 1), first);
    final evicted = !identical(cache.obtain(ContourGeometryTestData.rectangle(left: 1), pixelRatio: 1), second);
    expect(retained && evicted, isTrue);
  });

  test('when a source exceeds the byte limit, it should return usable geometry without retaining it', () {
    final cache = ContourGeometryCache.test(maximumSourceBytes: 1);
    final result = cache.obtain(ContourGeometryTestData.rectangle(), pixelRatio: 1);
    expect((cache.sourceCount, cache.sourceBytes, result.bounds), (0, 0, const ui.Rect.fromLTWH(0, 0, 12, 12)));
  });

  test('when the retained byte limit is small, it should bound the complete source allowance', () {
    final cache = ContourGeometryCache.test(maximumSourceBytes: 2200);
    for (var i = 0; i < 20; i++) {
      cache.obtain(ContourGeometryTestData.rectangle(left: i.toDouble()), pixelRatio: 1);
    }
    expect(cache.sourceCount > 0 && cache.sourceBytes <= 2200, isTrue);
  });

  test('when the native Path allowance crosses the byte limit, it should avoid retaining its key', () {
    final cache = ContourGeometryCache.test(maximumSourceBytes: 1000)
      ..obtain(ContourGeometryTestData.rectangle(), pixelRatio: 1);
    expect((cache.sourceCount, cache.sourceBytes), (0, 0));
  });

  test('when a cache is cleared, it should release its retained sources', () {
    final cache = ContourGeometryCache.test()
      ..obtain(ContourGeometryTestData.rectangle(), pixelRatio: 1)
      ..clear();
    expect((cache.sourceCount, cache.sourceBytes), (0, 0));
  });

  test('when caller arrays mutate, it should compare against an owned immutable key', () {
    final cache = ContourGeometryCache.test();
    final input = ContourGeometryTestData.rectangle();
    final first = cache.obtain(input, pixelRatio: 1);
    input.first[0] = 999;
    expect(identical(cache.obtain(ContourGeometryTestData.rectangle(), pixelRatio: 1), first), isTrue);
  });

  test('when cached metadata is evicted, it should leave an existing source usable', () {
    final cache = ContourGeometryCache.test(maximumSources: 1);
    final first = cache.obtain(ContourGeometryTestData.rectangle(), pixelRatio: 1);
    cache
      ..obtain(ContourGeometryTestData.rectangle(left: 50), pixelRatio: 1)
      ..clear();
    expect(first.shape.contains(const ui.Offset(6, 6)), isTrue);
  });
}
