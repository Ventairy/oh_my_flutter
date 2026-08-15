part of 'morph.dart';

final class _MorphTextRasterPoolFinalizerToken {
  final Set<ui.Image> images = <ui.Image>{};

  void dispose() {
    images
      ..forEach(_disposeImage)
      ..clear();
  }

  static void _disposeImage(ui.Image image) {
    image.dispose();
  }
}
