import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Reuses immutable native mask recordings without retaining their source widgets.
///
/// This internal cache is deliberately keyed by an accepted native proof rather
/// than sampled geometry: two fonts can have the same sampled outline while
/// their native glyph curves still differ.
class ContourNativeMaskPictureCache {
  new _({
    int maximumBytes = maximumEstimatedBytes,
    int maximumEntries = 128,
    int amountsPerSource = 4,
  }) : _maximumBytes = maximumBytes,
       _maximumEntries = maximumEntries,
       _amountsPerSource = amountsPerSource,
       assert(maximumBytes >= 0, 'The picture budget must be nonnegative.'),
       assert(maximumEntries >= 0, 'The entry limit must be nonnegative.'),
       assert(amountsPerSource >= 0, 'The amount limit must be nonnegative.');

  /// Creates an isolated cache with small limits for lifecycle regressions.
  @visibleForTesting
  new test({
    int maximumBytes = maximumEstimatedBytes,
    int maximumEntries = 128,
    int amountsPerSource = 4,
  }) : this._(
         maximumBytes: maximumBytes,
         maximumEntries: maximumEntries,
         amountsPerSource: amountsPerSource,
       );

  /// The retained-picture budget, including an allowance for glyph resources.
  static const int maximumEstimatedBytes = 4 * 1024 * 1024;

  /// The shared cache used by mounted contour owners.
  static final instance = ContourNativeMaskPictureCache._();

  final int _maximumBytes;
  final int _maximumEntries;
  final int _amountsPerSource;
  final _entries =
      <(Object, double, (double, double, double, double, ui.ColorSpace)), ({ui.Picture picture, int bytes})>{};
  final _amountCounts = <Object, int>{};
  final _lastAmounts = <(Object, (double, double, double, double, ui.ColorSpace)), double>{};
  int _estimatedBytes = 0;
  int _buildCount = 0;

  /// The number of retained recordings.
  int get entryCount => _entries.length;

  /// Estimated bytes retained by recordings and their glyph resources.
  int get estimatedBytes => _estimatedBytes;

  /// The number of recordings created by this cache.
  int get buildCount => _buildCount;

  /// The number of source and color variants awaiting repeated use.
  int get admissionSourceCount => _lastAmounts.length;

  /// The number of retained amount and color variants for an accepted source.
  int amountCount(Object sourceId) => _amountCounts[sourceId] ?? 0;

  /// Whether a white-mask amount is retained for an accepted source.
  @visibleForTesting
  bool contains(Object sourceId, double amount) =>
      _entries.containsKey((sourceId, amount, _colorKey(const ui.Color(0xFFFFFFFF))));

  /// Paints an existing recording without constructing its source callback.
  bool paintCached(
    ui.Canvas canvas, {
    required Object sourceId,
    required double amount,
    ui.Color color = const ui.Color(0xFFFFFFFF),
  }) {
    final key = (sourceId, amount, _colorKey(color));
    final existing = _entries.remove(key);
    if (existing == null) return false;
    _entries[key] = existing;
    final admissionKey = (sourceId, _colorKey(color));
    if (_lastAmounts[admissionKey] != amount) _remember(admissionKey, amount);
    canvas.drawPicture(existing.picture);
    return true;
  }

  /// Paints a mask and records an amount and color after their repeated use.
  ///
  /// [sourceId] must be an opaque identity created for one accepted native
  /// proof. [sourceBytes] includes the text and captured-geometry allowance;
  /// [ui.Picture.approximateBytesUsed] omits referenced glyph resources.
  /// Each source and color remembers its latest amount independently so a
  /// white shadow mask does not interrupt reuse of a colored foreground.
  /// A unique changing amount paints directly. The callback and its source
  /// objects are never retained.
  void paint(
    ui.Canvas canvas, {
    required Object sourceId,
    required double amount,
    required int sourceBytes,
    required void Function(ui.Canvas canvas) paint,
    ui.Color color = const ui.Color(0xFFFFFFFF),
  }) {
    assert(sourceBytes >= 0, 'The source allowance must be nonnegative.');
    if (sourceBytes >= _maximumBytes || _maximumEntries == 0 || _amountsPerSource == 0) {
      paint(canvas);
      return;
    }
    if (paintCached(canvas, sourceId: sourceId, amount: amount, color: color)) return;
    if (!_remember((sourceId, _colorKey(color)), amount)) {
      paint(canvas);
      return;
    }
    final key = (sourceId, amount, _colorKey(color));
    final recorder = ui.PictureRecorder();
    paint(ui.Canvas(recorder));
    final picture = recorder.endRecording();
    _buildCount++;
    final bytes = picture.approximateBytesUsed + sourceBytes;
    canvas.drawPicture(picture);
    if (bytes > _maximumBytes) {
      picture.dispose();
      return;
    }
    while (amountCount(sourceId) >= _amountsPerSource) {
      _remove(_entries.keys.firstWhere((candidate) => identical(candidate.$1, sourceId)));
    }
    while (_entries.isNotEmpty && (_entries.length >= _maximumEntries || _estimatedBytes + bytes > _maximumBytes)) {
      _remove(_entries.keys.first);
    }
    _entries[key] = (picture: picture, bytes: bytes);
    _amountCounts[sourceId] = amountCount(sourceId) + 1;
    _estimatedBytes += bytes;
  }

  bool _remember((Object, (double, double, double, double, ui.ColorSpace)) key, double amount) {
    final previous = _lastAmounts.remove(key);
    _lastAmounts[key] = amount;
    if (_lastAmounts.length > _maximumEntries) _lastAmounts.remove(_lastAmounts.keys.first);
    return previous == amount;
  }

  static (double, double, double, double, ui.ColorSpace) _colorKey(ui.Color color) =>
      (color.a, color.r, color.g, color.b, color.colorSpace);

  void _remove((Object, double, (double, double, double, double, ui.ColorSpace)) key) {
    final removed = _entries.remove(key)!;
    _estimatedBytes -= removed.bytes;
    final remaining = _amountCounts[key.$1]! - 1;
    if (remaining == 0) {
      _amountCounts.remove(key.$1);
    } else {
      _amountCounts[key.$1] = remaining;
    }
    removed.picture.dispose();
  }

  /// Disposes all retained recordings when fonts or mounted owners change.
  void clear() {
    for (final entry in _entries.values) {
      entry.picture.dispose();
    }
    _entries.clear();
    _amountCounts.clear();
    _lastAmounts.clear();
    _estimatedBytes = 0;
  }
}
