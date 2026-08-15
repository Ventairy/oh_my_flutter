part of 'morph.dart';

final class _MorphTextRasterPoolReservation {
  _MorphTextRasterPoolReservation(this.key);

  final _MorphTextRasterPoolKey key;
  ui.Image? image;

  ui.Image takeImage() {
    final result = image;
    if (result == null) {
      throw StateError(
        'A completed Morph raster reservation must own its image.',
      );
    }
    image = null;
    return result;
  }

  void disposeImage() {
    image?.dispose();
    image = null;
  }
}
