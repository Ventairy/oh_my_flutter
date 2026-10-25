import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

part 'contour_geometry.dart';

/// Reuses exact accepted source geometry across equivalent Contour owners.
class ContourGeometryCache {
  new _({int maximumSourceBytes = 4 * 1024 * 1024, int maximumSources = 64, int hashMask = 0x3fffffff})
    : _maximumSourceBytes = maximumSourceBytes,
      _maximumSources = maximumSources,
      _hashMask = hashMask,
      assert(maximumSourceBytes >= 0, 'The source budget must be nonnegative.'),
      assert(maximumSources >= 0, 'The source count limit must be nonnegative.'),
      assert(hashMask >= 0 && hashMask <= 0x3fffffff, 'The hash mask must fit thirty bits.');

  /// Creates an isolated cache with small limits for reuse regressions.
  @visibleForTesting
  new test({int maximumSourceBytes = 4 * 1024 * 1024, int maximumSources = 64, int hashMask = 0x3fffffff})
    : this._(maximumSourceBytes: maximumSourceBytes, maximumSources: maximumSources, hashMask: hashMask);

  /// The shared geometry cache used by mounted Contours.
  static final instance = ContourGeometryCache._();

  final int _maximumSourceBytes;
  final int _maximumSources;
  final int _hashMask;
  final _sources = <ContourGeometry, ({List<Float64List> curves, int bytes})>{};
  final _buckets = <int, List<ContourGeometry>>{};
  int _sourceBytes = 0;
  int _sourceHits = 0;
  int _sourceBuilds = 0;

  /// The number of canonical source descriptions retained for reuse.
  int get sourceCount => _sources.length;

  /// Estimated storage retained by canonical sources and their exact keys.
  int get sourceBytes => _sourceBytes;

  /// The number of source requests reusing exact accepted coordinates.
  int get sourceHits => _sourceHits;

  /// The number of source fills constructed.
  int get sourceBuilds => _sourceBuilds;

  /// Reuses a source when its complete logical coordinates match exactly.
  ///
  /// Accepted capture arrays are copied only when their geometry is retained
  /// for later comparisons. Existing source values remain valid after eviction.
  ContourGeometry obtain(
    List<Float64List> curves, {
    required double pixelRatio,
    ui.Offset origin = ui.Offset.zero,
  }) {
    assert(pixelRatio.isFinite && pixelRatio > 0, 'The capture density must be finite and positive.');
    assert(origin.dx.isFinite && origin.dy.isFinite, 'The capture origin must be finite.');
    var hash = 17;
    var keyBytes = 128;
    var pathBytes = 256;
    for (final curve in curves) {
      assert(curve.length >= 8 && (curve.length - 2) % 6 == 0, 'A contour must contain complete cubic segments.');
      keyBytes += curve.lengthInBytes + 64;
      pathBytes += curve.lengthInBytes * 2 + 32;
      hash = (hash * 31 + curve.length) & _hashMask;
      for (var i = 0; i < curve.length; i++) {
        final value = curve[i] / pixelRatio + (i.isEven ? origin.dx : origin.dy);
        assert(value.isFinite, 'Accepted contour coordinates must be finite.');
        hash = (hash * 31 + value.hashCode) & _hashMask;
      }
    }
    for (final source in _buckets[hash] ?? const <ContourGeometry>[]) {
      final entry = _sources[source]!;
      if (!_same(entry.curves, curves, pixelRatio, origin)) continue;
      _sources
        ..remove(source)
        ..[source] = entry;
      _sourceHits++;
      return source;
    }
    _sourceBuilds++;
    final estimatedBytes = keyBytes + pathBytes;
    if (_maximumSources == 0 || estimatedBytes > _maximumSourceBytes) {
      return ContourGeometry._(hash, curves, pixelRatio: pixelRatio, origin: origin);
    }
    // Reserve the incoming entry before copying its key or building its Path,
    // keeping old and incoming retained geometry within one shared allowance.
    while (_sources.isNotEmpty &&
        (_sources.length >= _maximumSources || _sourceBytes + estimatedBytes > _maximumSourceBytes)) {
      final oldest = _sources.keys.first;
      _sourceBytes -= _sources.remove(oldest)!.bytes;
      final bucket = _buckets[oldest._hash]!..remove(oldest);
      if (bucket.isEmpty) _buckets.remove(oldest._hash);
    }
    final logical = <Float64List>[];
    for (final curve in curves) {
      final values = Float64List(curve.length);
      for (var i = 0; i < curve.length; i++) {
        values[i] = curve[i] / pixelRatio + (i.isEven ? origin.dx : origin.dy);
      }
      logical.add(values.asUnmodifiableView());
    }
    final source = ContourGeometry._(hash, logical, pixelRatio: 1, origin: ui.Offset.zero);
    final bytes = keyBytes + source.estimatedBytes;
    assert(bytes == estimatedBytes, 'Source admission must include its complete retained allowance.');
    _sources[source] = (curves: List<Float64List>.unmodifiable(logical), bytes: bytes);
    (_buckets[hash] ??= []).add(source);
    _sourceBytes += bytes;
    return source;
  }

  bool _same(List<Float64List> logical, List<Float64List> captured, double ratio, ui.Offset origin) {
    if (captured.length != logical.length) return false;
    for (var i = 0; i < logical.length; i++) {
      final source = logical[i];
      final candidate = captured[i];
      if (source.length != candidate.length) return false;
      for (var j = 0; j < source.length; j++) {
        if (source[j] != candidate[j] / ratio + (j.isEven ? origin.dx : origin.dy)) return false;
      }
    }
    return true;
  }

  /// Discards reuse entries while leaving existing source values valid.
  void clear() {
    _sources.clear();
    _buckets.clear();
    _sourceBytes = 0;
  }
}
