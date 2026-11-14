part of '../../motion.dart';

class _MotionTextureReadiness {
  new({
    required this.texture,
    required this.handle,
    required this.size,
    required this.probeWidth,
    required this.contentTop,
  });

  final int texture;
  final int handle;
  final Size size;
  final int probeWidth;
  final double contentTop;
  bool _disposed = false;

  Future<bool> waitForImage() async {
    final elapsed = Stopwatch()..start();
    while (!_disposed && elapsed.elapsed < const Duration(seconds: 1)) {
      final scene =
          (ui.SceneBuilder()..addTexture(texture, width: size.width, height: size.height, filterQuality: .none))
              .build();
      ui.Image? image;
      try {
        image = await scene.toImage(probeWidth, 1);
        final pixels = await image.toByteData();
        if (_disposed) return false;
        if (pixels != null && _matchesHandle(pixels)) return true;
      } finally {
        image?.dispose();
        scene.dispose();
      }
      await WidgetsBinding.instance.endOfFrame;
    }
    return false;
  }

  void dispose() => _disposed = true;

  bool _matchesHandle(ByteData pixels) {
    for (var pixel = 0; pixel < probeWidth; pixel++) {
      if (pixels.getUint8(pixel * 4 + 3) != 255) return false;
      for (var channel = 0; channel < 3; channel++) {
        final bit = pixel * 3 + channel;
        final expected = bit < 64 && ((handle >> bit) & 1) != 0;
        if ((pixels.getUint8(pixel * 4 + channel) >= 128) != expected) return false;
      }
    }
    return true;
  }
}
