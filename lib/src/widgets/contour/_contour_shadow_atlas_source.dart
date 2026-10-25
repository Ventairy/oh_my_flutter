part of 'contour.dart';

class _ContourShadowAtlasSource {
  new _(this.pictures, this._bytes);

  // Recordings retain glyph/path resources that approximateBytesUsed omits.
  // Charge the source allowance for every amount, and bound queued recordings
  // as well as the GPU images produced from them.
  static const int _maximumBytes = 4 * 1024 * 1024;
  static int retainedBytes = 0;

  final List<ui.Picture> pictures;
  final int _bytes;

  static _ContourShadowAtlasSource? record({
    required double minimumAmount,
    required int sourceBytes,
    required ui.Picture Function(double amount) recordMask,
  }) {
    final allowance = sourceBytes * _ContourShadowAtlas.frames;
    if (allowance > _maximumBytes - retainedBytes) return null;
    final pictures = <ui.Picture>[];
    var bytes = allowance;
    var retained = false;
    try {
      for (var index = 0; index < _ContourShadowAtlas.frames; index++) {
        final picture = recordMask(minimumAmount + index);
        pictures.add(picture);
        bytes += picture.approximateBytesUsed;
        if (bytes > _maximumBytes - retainedBytes) return null;
      }
      retainedBytes += bytes;
      retained = true;
      return _ContourShadowAtlasSource._(pictures, bytes);
    } finally {
      if (!retained) {
        for (final picture in pictures) {
          picture.dispose();
        }
      }
    }
  }

  void dispose() {
    for (final picture in pictures) {
      picture.dispose();
    }
    retainedBytes -= _bytes;
  }
}
